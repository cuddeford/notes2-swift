import SwiftUI
import SwiftData
import Foundation
import UIKit
import Combine

struct NoteContextMenuModifier: ViewModifier {
    let note: Note
    @Binding var selectedNoteID: UUID?
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .contextMenu(
                menuItems: {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        selectedNoteID = note.id
                    } label: {
                        Label("Open", systemImage: "long.text.page.and.pencil")
                    }

                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        note.isPinned.toggle()
                        if note.isPinned {
                            note.pinnedAt = Date()
                        } else {
                            note.pinnedAt = nil
                        }
                    } label: {
                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash.fill" : "pin.fill")
                    }

                    Button(role: .destructive) {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        context.delete(note)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                },
                preview: {
                    NavigationStack {
                        NoteView(note: note, selectedNoteID: .constant(nil), isPreview: true)
                    }
                }
            )
    }
}

extension View {
    func noteContextMenu(for note: Note, selectedNoteID: Binding<UUID?>) -> some View {
        modifier(NoteContextMenuModifier(note: note, selectedNoteID: selectedNoteID))
    }
}

struct ContentView: View {
    @Query(sort: \Note.createdAt, order: .reverse) var notes: [Note]
    @Environment(\ .modelContext) private var context
    @Environment(\ .horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("recentsExpanded") private var recentsExpanded = true
    @AppStorage("historyExpanded") private var historyExpanded = true
    @AppStorage("pinnedExpanded") private var pinnedExpanded = true
    @State private var historicalExpanded: [String: Bool] = [: ]
    @State private var hasRestoredLastOpenedNote = false
    @State private var selectedNoteID: UUID?
    @State private var selectedCompositeID: String?
    @State private var isShowingSettings = false
    @StateObject var settings = AppSettings.shared

    @State private var listDragOffset: CGSize = .zero
    @State private var listDragLocation: CGPoint = .zero
    @State private var isListDragging = false
    @State private var searchText = ""

    private func binding(for day: Date) -> Binding<Bool> {
        let key = ISO8601DateFormatter().string(from: day)
        return .init(
            get: { self.historicalExpanded[key, default: true] },
            set: { self.historicalExpanded[key] = $0 }
        )
    }

    var body: some View {
        let filteredNotes = searchText.isEmpty ? notes : notes.filter { note in
            let searchLower = searchText.lowercased()
            return note.firstLine.lowercased().localizedCaseInsensitiveContains(searchLower) ||
                   note.plain.lowercased().localizedCaseInsensitiveContains(searchLower)
        }
        let recentNotes = filteredNotes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(settings.recentsCount)

        return NavigationView {
            let groupedNotes = Dictionary(grouping: filteredNotes) { note in
                Calendar.current.startOfDay(for: note.createdAt)
            }
            let sortedDays = groupedNotes.keys.sorted(by: >)
            let pinnedNotes = filteredNotes.filter { $0.isPinned }.sorted(by: { $0.pinnedAt ?? Date.distantPast > $1.pinnedAt ?? Date.distantPast })

            List {
                if !searchText.isEmpty {
                    if filteredNotes.isEmpty {
                        Section {
                            Text("No notes found matching \u{200d}\(searchText)")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    } else {
                        Section(header: Text("Search Results")) {
                            ForEach(filteredNotes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        self.selectedNoteID = note.id
                                    }
                                    .noteContextMenu(for: note, selectedNoteID: $selectedNoteID)
                            }
                        }
                    }
                } else {
                    if pinnedVisible && !pinnedNotes.isEmpty {
                        Section(isExpanded: $pinnedExpanded) {
                            ForEach(pinnedNotes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        self.selectedNoteID = note.id
                                    }
                                    .noteContextMenu(for: note, selectedNoteID: $selectedNoteID)
                            }
                        } header: {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                    }

                    if recentsVisible && !recentNotes.isEmpty {
                        Section(isExpanded: $recentsExpanded) {
                            ForEach(recentNotes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        self.selectedNoteID = note.id
                                    }
                                    .noteContextMenu(for: note, selectedNoteID: $selectedNoteID)
                            }
                        } header: {
                            Label("Recents", systemImage: "clock.fill")
                        }
                    }

                    if historyVisible {
                        Section(isExpanded: $historyExpanded) {
                            ForEach(sortedDays, id: \.self) { day in
                                Section(isExpanded: binding(for: day)) {
                                    ForEach(groupedNotes[day] ?? []) { note in
                                        NoteRow(note: note)
                                            .onTapGesture {
                                                self.selectedNoteID = note.id
                                            }
                                            .noteContextMenu(for: note, selectedNoteID: $selectedNoteID)
                                    }
                                } header: {
                                    HStack {
                                        Text(day.formattedDate())
                                        Spacer()
                                        Text(day.relativeDate())
                                            .fontWeight(day.relativeDate() == "Today" ? .bold : .regular)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Label("History", systemImage: "calendar")
                        }
                    }
                }
            }
            .animation(.default, value: pinnedExpanded)
            .animation(.default, value: recentsExpanded)
            .animation(.default, value: historyExpanded)
            .animation(.default, value: historicalExpanded)
            .animation(.default, value: pinnedVisible)
            .animation(.default, value: recentsVisible)
            .animation(.default, value: historyVisible)
            .navigationTitle("Spring")
            .searchable(text: $searchText, placement: .automatic, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let newNote = Note()
                        context.insert(newNote)
                        selectedNoteID = newNote.id
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationView {
                    SettingsView()
                }
            }
            .fullScreenCover(item: $selectedNoteID) { noteID in
                if let note = notes.first(where: { $0.id == noteID }) {
                    NoteView(note: note, selectedNoteID: $selectedNoteID)
                }
            }
            .onChange(of: historicalExpanded) { oldValue, newValue in
                if let encoded = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(encoded, forKey: "historicalExpanded")
                }
            }
            .onAppear {
                if !hasRestoredLastOpenedNote {
                    hasRestoredLastOpenedNote = true
                    if let idString = UserDefaults.standard.string(forKey: "lastOpenedNoteID"),
                       let uuid = UUID(uuidString: idString) {
                        self.selectedNoteID = uuid
                    }
                }

                if let data = UserDefaults.standard.data(forKey: "historicalExpanded") {
                    if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                        self.historicalExpanded = decoded
                    }
                }
            }
        }
        .overlay {
            if isListDragging && settings.lastNoteIndicatorGestureEnabled {
                let isUntitled = recentNotes.first?.firstLine.isEmpty ?? true
                LastNoteIndicatorView(translation: listDragOffset, location: listDragLocation, noteFirstLine: isUntitled ? "empty" : recentNotes.first!.firstLine, isUntitled: isUntitled)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .global)
                .onChanged { value in
                    guard settings.lastNoteIndicatorGestureEnabled else { return }

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
                    guard settings.lastNoteIndicatorGestureEnabled else { return }

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
        .tint(color(from: settings.accentColor))
    }
}

#Preview {
    ContentView()
}

extension UUID: Identifiable {
    public var id: UUID { self }
}

extension Notification.Name {
    static let sidebarStateChanged = Notification.Name("SidebarStateChangedNotification")
}
