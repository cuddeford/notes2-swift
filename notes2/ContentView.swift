

import SwiftUI
import SwiftData
import Foundation
import UIKit
import Combine

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
    @AppStorage("newNoteWithBigFont") private var newNoteWithBigFont = true

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
        NavigationView {
            let filteredNotes = searchText.isEmpty ? notes : notes.filter { note in
                let searchLower = searchText.lowercased()
                return note.firstLine.lowercased().localizedCaseInsensitiveContains(searchLower) ||
                       note.plain.lowercased().localizedCaseInsensitiveContains(searchLower)
            }

            let groupedNotes = Dictionary(grouping: filteredNotes) { note in
                Calendar.current.startOfDay(for: note.createdAt)
            }
            let sortedDays = groupedNotes.keys.sorted(by: >)

            let recentNotes = filteredNotes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(2)
            let pinnedNotes = filteredNotes.filter { $0.isPinned }.sorted(by: { $0.pinnedAt ?? Date.distantPast > $1.pinnedAt ?? Date.distantPast })

            List {
                if !searchText.isEmpty {
                    if filteredNotes.isEmpty {
                        Section {
                            Text("No notes found matching \"\u{200b}\(searchText)\"")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    } else {
                        Section(header: Text("Search Results")) {
                            ForEach(filteredNotes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        self.selectedNoteID = note.id
                                    }
                            }
                        }
                    }
                } else {
                    if pinnedVisible && !pinnedNotes.isEmpty {
                        Section(isExpanded: $pinnedExpanded) {
                            ForEach(pinnedNotes) { note in
                                NoteRow(note: note)
                                    .onTapGesture {
                                        self.selectedNoteID = note.id
                                    }
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
                                        self.selectedNoteID = note.id
                                    }
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
            .navigationTitle("Notes2")
            .searchable(text: $searchText, placement: .automatic, prompt: "Search notes...")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("Show pinned section", isOn: $pinnedVisible)
                        Toggle("Show recents section", isOn: $recentsVisible)
                        Toggle("Show history section", isOn: $historyVisible)
                        Divider()
                        Toggle("Magnetic scrolling", isOn: Binding(
                            get: { AppSettings.shared.magneticScrollingEnabled },
                            set: { AppSettings.shared.magneticScrollingEnabled = $0 }
                        ))
                        Toggle("New notes start with big font", isOn: $newNoteWithBigFont)
                        Toggle("Drag to reorder paragraph (WIP)", isOn: Binding(
                            get: { AppSettings.shared.dragToReorderParagraphEnabled },
                            set: { AppSettings.shared.dragToReorderParagraphEnabled = $0 }
                        ))
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                    }
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
