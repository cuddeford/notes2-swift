//
//  ContentView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

@Model
class Note: Identifiable, Hashable {
    var id: UUID = UUID()
    var content: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var cursorLocation: Int = 0
    var isPinned: Bool = false

    init(id: UUID = UUID(), content: Data = Data(), createdAt: Date = Date(), updatedAt: Date = Date(), cursorLocation: Int = 0, isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cursorLocation = cursorLocation
        self.isPinned = isPinned
    }

    static func == (lhs: Note, rhs: Note) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Note {
    var firstLine: String {
        if let attr = try? NSAttributedString(
            data: self.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            let plain = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstLine = plain.components(separatedBy: .newlines).first {
                return firstLine.isEmpty ? "" : firstLine
            }
        }

        return ""
    }

    var plain: String {
        if let attr = try? NSAttributedString(
            data: self.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            return attr.string.isEmpty
                ? ""
                : attr.string
        }

        return ""
    }
}

struct ContentView: View {
    @Query(sort: \Note.createdAt, order: .reverse) var notes: [Note]
    @Environment(\.modelContext) private var context

    @AppStorage("recentsExpanded") private var recentsExpanded = true
    @AppStorage("historyExpanded") private var historyExpanded = true
    @AppStorage("pinnedExpanded") private var pinnedExpanded = true
    @State private var historicalExpanded: [String: Bool] = [:]
    @State private var hasRestoredLastOpenedNote = false
    @State private var selectedNoteID: UUID?

    @State private var listDragOffset: CGSize = .zero
    @State private var listDragLocation: CGPoint = .zero
    @State private var isListDragging = false

    private func binding(for day: Date) -> Binding<Bool> {
        let key = ISO8601DateFormatter().string(from: day)
        return .init(
            get: { self.historicalExpanded[key, default: true] },
            set: { self.historicalExpanded[key] = $0 }
        )
    }

    var body: some View {
        let groupedNotes = Dictionary(grouping: notes) { note in
            Calendar.current.startOfDay(for: note.createdAt)
        }
        let sortedDays = groupedNotes.keys.sorted(by: >)

        let recentNotes = notes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(2)
        let pinnedNotes = notes.filter { $0.isPinned }.sorted(by: { $0.updatedAt > $1.updatedAt })

        NavigationSplitView(columnVisibility: .constant(.all)) {
            ZStack {
                NavigationStack {
                    List(selection: $selectedNoteID) {
                        if !pinnedNotes.isEmpty {
                            Section(isExpanded: $pinnedExpanded) {
                                ForEach(pinnedNotes) { note in
                                    NavigationLink(value: note.id) {
                                        NoteRow(note: note)
                                    }
                                    .tag(note.id)
                                }
                            } header: {
                                Label("Pinned", systemImage: "pin.fill")
                            }
                        }

                        if !recentNotes.isEmpty {
                            Section(isExpanded: $recentsExpanded) {
                                ForEach(recentNotes) { note in
                                    NavigationLink(value: note.id) {
                                        NoteRow(note: note)
                                    }
                                    .tag(note.id)
                                }
                            } header: {
                                Label("Recents", systemImage: "clock.fill")
                            }
                        }

                        Section(isExpanded: $historyExpanded) {
                            ForEach(sortedDays, id: \.self) { day in
                                Section(isExpanded: binding(for: day)) {
                                    ForEach(groupedNotes[day] ?? []) { note in
                                    NavigationLink(value: note.id) {
                                        NoteRow(note: note)
                                    }
                                    .tag(note.id)
                                }
                                } header: {
                                    HStack {
                                        Text(day.formattedDate())
                                        Spacer()
                                        Text(day.relativeDate())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Label("History", systemImage: "calendar")
                        }
                    }
                    .animation(.default, value: pinnedExpanded)
                    .animation(.default, value: recentsExpanded)
                    .animation(.default, value: historyExpanded)
                    .animation(.default, value: historicalExpanded)
                    .navigationTitle("Notes2")
                    .navigationDestination(for: UUID.self) { noteID in
                        if let note = notes.first(where: { $0.id == noteID }) {
                            NoteView(note: note, selectedNoteID: $selectedNoteID)
                                .environment(\.modelContext, context)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                let newNote = Note()
                                context.insert(newNote)
                                selectedNoteID = newNote.id
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("New note")
                                }
                            }
                        }
                    }
                    .onChange(of: historicalExpanded) { oldValue, newValue in
                        if let encoded = try? JSONEncoder().encode(newValue) {
                            UserDefaults.standard.set(encoded, forKey: "historicalExpanded")
                        }
                    }
                }
                .task {
                    guard !hasRestoredLastOpenedNote else { return }
                    hasRestoredLastOpenedNote = true

                    if let idString = UserDefaults.standard.string(forKey: "lastOpenedNoteID"),
                       let uuid = UUID(uuidString: idString),
                       let note = notes.first(where: { $0.id == uuid }) {
                        selectedNoteID = note.id
                    }

                    if let data = UserDefaults.standard.data(forKey: "historicalExpanded") {
                        if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                            self.historicalExpanded = decoded
                        }
                    }
                }
                if isListDragging {
                    LastNoteIndicatorView(translation: listDragOffset, location: listDragLocation)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 25, coordinateSpace: .global)
                    .onChanged { value in
                        // Only activate if the drag starts from the right edge of the screen
                        if value.startLocation.x > UIScreen.main.bounds.width - 50 {
                            // Set the location first
                            listDragOffset = value.translation
                            listDragLocation = value.location

                            // Then animate the appearance if it's not already visible
                            if !isListDragging {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isListDragging = true
                                }
                            }
                        }
                    }
                    .onEnded { value in
                        if isListDragging, value.translation.width < -100 { // Swipe left
                            if let lastEdited = recentNotes.first {
                                selectedNoteID = lastEdited.id
                            }
                        }
                        // Reset drag state
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isListDragging = false
                        }
                        listDragOffset = .zero
                        listDragLocation = .zero
                    }
            )
        } detail: {
            if let selectedNoteID {
                if let note = notes.first(where: { $0.id == selectedNoteID }) {
                    NoteView(note: note, selectedNoteID: $selectedNoteID)
                        .environment(\.modelContext, context)
                }
            } else {
                Text("Select a note")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LastNoteIndicatorView: View {
    var translation: CGSize
    var location: CGPoint

    @State private var lastWillCreateNote: Bool = false

    var body: some View {
        let willCreateNote = translation.width < -100
        let backgroundColor = willCreateNote ? Color.green : Color.red

        let topInset = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.safeAreaInsets.top ?? 0

        Text("Go to last edited note")
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .position(x: UIScreen.main.bounds.width + translation.width - 60, y: location.y - 150 - topInset)
            .animation(.interactiveSpring(), value: translation)
            .transition(.opacity)
            .onChange(of: willCreateNote) { oldValue, newValue in
                if oldValue != newValue {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

struct NoteView: View {
    @Bindable var note: Note
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var context: ModelContext

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    @State private var dragOffset: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false

    init(note: Note, selectedNoteID: Binding<UUID?>) {
        self._selectedNoteID = selectedNoteID
        self._note = Bindable(wrappedValue: note)

        if let attr = try? NSAttributedString(
            data: note.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil,
        ) {
            _noteText = State(initialValue: attr)
        } else {
            _noteText = State(initialValue: NSAttributedString(string: ""))
        }

        _selectedRange = State(initialValue: NSRange(location: note.cursorLocation, length: 0))
    }

    var body: some View {
        ZStack {
            RichTextEditor(
                text: $noteText,
                selectedRange: $selectedRange,
                note: note,
                keyboard: keyboard,
                onCoordinatorReady: { coordinator in
                    self.editorCoordinator = coordinator
                    if noteText.length == 0 {
                        coordinator.toggleAttribute(.title1)
                    }

                    // focus the editor
                    coordinator.textView?.becomeFirstResponder()
                },
            )
            .onChange(of: noteText) { oldValue, newValue in
                if let data = try? newValue.data(
                    from: NSRange(location: 0, length: newValue.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd],
                ) {
                    note.content = data
                    note.updatedAt = Date()
                }
            }

            if isDragging {
                NewNoteIndicatorView(translation: dragOffset, location: dragLocation)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .global)
                .onChanged { value in
                    // Only activate if the drag starts from the right edge of the screen
                    if value.startLocation.x > UIScreen.main.bounds.width - 50 {
                        // Set the location first
                        dragOffset = value.translation
                        dragLocation = value.location

                        // Then animate the appearance if it's not already visible
                        if !isDragging {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                    }
                }
                .onEnded { value in
                    if isDragging, value.translation.width < -100 { // Swipe left
                        let newNote = Note()
                        context.insert(newNote)
                        selectedNoteID = nil
                        DispatchQueue.main.async {
                            selectedNoteID = newNote.id
                        }
                    }
                    // Reset drag state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDragging = false
                    }
                    dragOffset = .zero
                    dragLocation = .zero
                }
        )
        .ignoresSafeArea()
        .toolbar(UIDevice.current.userInterfaceIdiom == .phone ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            UserDefaults.standard.set(note.id.uuidString, forKey: "lastOpenedNoteID")
        }
        .onDisappear {
            UserDefaults.standard.removeObject(forKey: "lastOpenedNoteID")
        }
    }
}

struct NewNoteIndicatorView: View {
    var translation: CGSize
    var location: CGPoint

    @State private var lastWillCreateNote: Bool = false

    var body: some View {
        let willCreateNote = translation.width < -100
        let backgroundColor = willCreateNote ? Color.green : Color.red

        Text("New Note")
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .position(x: UIScreen.main.bounds.width + translation.width - 60, y: location.y - 50)
            .animation(.interactiveSpring(), value: translation)
            .transition(.opacity)
            .onChange(of: willCreateNote) { oldValue, newValue in
                if oldValue != newValue {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

#Preview {
    ContentView()
}
