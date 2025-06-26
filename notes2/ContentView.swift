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
    @Attribute(.unique) var id: UUID
    var content: Data
    var createdAt: Date
    var updatedAt: Date
    var cursorLocation: Int = 0
    var isPinned: Bool = false

    init(
        id: UUID = UUID(),
        content: Data = Data(),
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        cursorLocation: Int = 0
    ) {
        self.id = id
        self.content = content

        let now = Date()
        self.createdAt = createdAt ?? now
        self.updatedAt = updatedAt ?? now
        self.cursorLocation = cursorLocation
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

    @State private var path = NavigationPath()
    @AppStorage("recentsExpanded") private var recentsExpanded = true
    @AppStorage("historyExpanded") private var historyExpanded = true
    @AppStorage("pinnedExpanded") private var pinnedExpanded = true
    @State private var historicalExpanded: [String: Bool] = [:]
    @State private var hasRestoredLastOpenedNote = false

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

        NavigationSplitView {
            NavigationStack(path: $path) {
                List {
                    if !pinnedNotes.isEmpty {
                        Section(isExpanded: $pinnedExpanded) {
                            ForEach(pinnedNotes) { note in
                                NavigationLink(value: note) {
                                    NoteRow(note: note)
                                }
                            }
                        } header: {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                    }

                    if !recentNotes.isEmpty {
                        Section(isExpanded: $recentsExpanded) {
                            ForEach(recentNotes) { note in
                                NavigationLink(value: note) {
                                    NoteRow(note: note)
                                }
                            }
                        } header: {
                            Label("Recents", systemImage: "clock.fill")
                        }
                    }

                    Section(isExpanded: $historyExpanded) {
                        ForEach(sortedDays, id: \.self) { day in
                            Section(isExpanded: binding(for: day)) {
                                ForEach(groupedNotes[day] ?? []) { note in
                                    NavigationLink(value: note) {
                                        NoteRow(note: note)
                                    }
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
                .navigationDestination(for: Note.self) { note in
                    NoteView(note: note, path: $path)
                        .environment(\.modelContext, context)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            let newNote = Note()
                            context.insert(newNote)
                            path.append(newNote)
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
                    path.append(note)
                }

                if let data = UserDefaults.standard.data(forKey: "historicalExpanded") {
                    if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                        self.historicalExpanded = decoded
                    }
                }
            }
        } detail: {
            Text("Select a note")
                .foregroundStyle(.secondary)
        }
    }
}

struct NoteView: View {
    @Bindable var note: Note
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var context: ModelContext

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    @State private var rightEdgeGestureState: UIGestureRecognizer.State = .possible
    @State private var rightEdgeGestureTranslation: CGSize = .zero
    @State private var rightEdgeGestureLocation: CGPoint = .zero

    init(note: Note, path: Binding<NavigationPath>) {
        self._path = path
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
                    // coordinator.textView?.becomeFirstResponder()
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
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            UserDefaults.standard.set(note.id.uuidString, forKey: "lastOpenedNoteID")
        }
        .onDisappear {
            UserDefaults.standard.removeObject(forKey: "lastOpenedNoteID")
        }
        .onRightEdgeSwipe(gestureState: $rightEdgeGestureState, translation: $rightEdgeGestureTranslation, location: $rightEdgeGestureLocation) {
            let newNote = Note()
            context.insert(newNote)

            $path.wrappedValue.removeLast()
            DispatchQueue.main.async {
                $path.wrappedValue.append(newNote)
            }
        }

        if rightEdgeGestureState == .changed || rightEdgeGestureState == .began {
            NewNoteIndicatorView(translation: rightEdgeGestureTranslation, location: rightEdgeGestureLocation)
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

        GeometryReader { geometry in
            Text("New Note")
                .font(.headline)
                .padding()
                .background(backgroundColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .frame(maxWidth: .infinity, alignment: .trailing) // Push to the right
                .offset(x: translation.width) // Keep X as is
                .offset(y: location.y - 500) // Adjust Y using geometry.size.height
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
}

#Preview {
    ContentView()
}
