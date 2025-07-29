//
//  ContentView.swift
//  notes2
//
//  Simplified ContentView with essential functionality
//

import SwiftUI
import SwiftData
import Foundation

struct ContentView: View {
    @Query(sort: \Note.createdAt, order: .reverse) var notes: [Note]
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var hasRestoredLastOpenedNote = false
    @State private var selectedNoteID: UUID?
    @State private var selectedCompositeID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var searchText = ""
    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("recentsExpanded") private var recentsExpanded = true
    @AppStorage("historyExpanded") private var historyExpanded = true
    @AppStorage("pinnedExpanded") private var pinnedExpanded = true
    @State private var historicalExpanded: [String: Bool] = [:]
    
    private func binding(for day: Date) -> Binding<Bool> {
        let key = ISO8601DateFormatter().string(from: day)
        return Binding(
            get: { self.historicalExpanded[key, default: true] },
            set: { 
                self.historicalExpanded[key] = $0
                DispatchQueue.main.async {
                    if let encoded = try? JSONEncoder().encode(self.historicalExpanded) {
                        UserDefaults.standard.set(encoded, forKey: "historicalExpanded")
                    }
                }
            }
        )
    }

    var body: some View {
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
        let pinnedNotes = filteredNotes.filter { $0.isPinned }.sorted(by: { $0.updatedAt > $1.updatedAt })

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedCompositeID) {
                if !searchText.isEmpty {
                    // Search results
                    Section(header: Text("Search Results")) {
                        ForEach(filteredNotes) { note in
                            NoteRow(note: note)
                                .tag("search-\(note.id)")
                        }
                    }
                } else {
                    // Pinned notes
                    if pinnedVisible && !pinnedNotes.isEmpty {
                        Section(isExpanded: $pinnedExpanded) {
                            ForEach(pinnedNotes) { note in
                                NoteRow(note: note)
                                    .tag("pinned-\(note.id)")
                            }
                        } header: {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                    }

                    // Recent notes
                    if recentsVisible && !recentNotes.isEmpty {
                        Section(isExpanded: $recentsExpanded) {
                            ForEach(recentNotes) { note in
                                NoteRow(note: note)
                                    .tag("recents-\(note.id)")
                            }
                        } header: {
                            Label("Recents", systemImage: "clock.fill")
                        }
                    }

                    // History
                    if historyVisible {
                        Section(isExpanded: $historyExpanded) {
                            ForEach(sortedDays, id: \.self) { day in
                                Section(isExpanded: binding(for: day)) {
                                    ForEach(groupedNotes[day] ?? []) { note in
                                        NoteRow(note: note)
                                            .tag("history-\(note.id)")
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
            .navigationTitle("Notes")
            .searchable(text: $searchText, placement: .automatic, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createNewNote()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    settingsButton()
                }
            }
            .onAppear {
                handleAppLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                UserDefaults.standard.set(Date(), forKey: "lastForegroundDate")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                UserDefaults.standard.set(Date(), forKey: "lastForegroundDate")
            }
            .animation(.default, value: searchText)
            .animation(.default, value: pinnedVisible)
            .animation(.default, value: recentsVisible)
            .animation(.default, value: historyVisible)
        } detail: {
            if let selectedNoteID {
                if let note = notes.first(where: { $0.id == selectedNoteID }) {
                    NoteView(note: note, selectedNoteID: $selectedNoteID)
                        .id(selectedNoteID)
                        .environment(\.modelContext, context)
                } else {
                    Text("Note not found")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a note")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedCompositeID) { oldValue, newValue in
            handleCompositeSelection(newValue)
        }
        .onChange(of: selectedNoteID) { oldValue, newValue in
            if newValue != nil && horizontalSizeClass == .compact {
                columnVisibility = .detailOnly
            }
        }
    }
    
    private func createNewNote() {
        let newNote = Note()
        context.insert(newNote)
        selectedNoteID = newNote.id
        selectedCompositeID = "recents-\(newNote.id)"
    }
    
    private func handleAppLaunch() {
        guard !hasRestoredLastOpenedNote else { return }
        hasRestoredLastOpenedNote = true

        // Track app foregrounding
        UserDefaults.standard.set(Date(), forKey: "lastForegroundDate")

        let recentNotes = notes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(2)
        let decision = determineFreshNoteCreation(notes: notes, recentNotes: Array(recentNotes))
        
        if decision.createNew {
            let note = decision.reuseExisting ? decision.existingNote! : Note()
            if !decision.reuseExisting {
                context.insert(note)
            } else {
                note.updatedAt = Date()
            }
            selectedNoteID = note.id
            selectedCompositeID = "recents-\(note.id)"
        } else if let idString = UserDefaults.standard.string(forKey: "lastOpenedNoteID"),
                  let uuid = UUID(uuidString: idString),
                  let note = notes.first(where: { $0.id == uuid }) {
            selectedNoteID = note.id
            let allPinnedNotes = notes.filter { $0.isPinned }.sorted(by: { $0.updatedAt > $1.updatedAt })
            let allRecentNotes = notes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(2)
            
            if allPinnedNotes.contains(where: { $0.id == uuid }) {
                selectedCompositeID = "pinned-\(uuid)"
            } else if allRecentNotes.contains(where: { $0.id == uuid }) {
                selectedCompositeID = "recents-\(uuid)"
            } else {
                selectedCompositeID = "history-\(uuid)"
            }
        }

        if let data = UserDefaults.standard.data(forKey: "historicalExpanded") {
            if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                self.historicalExpanded = decoded
            }
        }
    }
    
    private func handleCompositeSelection(_ compositeID: String?) {
        guard let compositeID = compositeID else {
            selectedNoteID = nil
            return
        }
        
        let parts = compositeID.split(separator: "-", maxSplits: 1)
        if parts.count > 1, let noteID = UUID(uuidString: String(parts[1])) {
            selectedNoteID = noteID
        }
    }
    
    // MARK: - Fresh Note System
    
    private struct FreshNoteDecision {
        let createNew: Bool
        let reuseExisting: Bool
        let existingNote: Note?
    }
    
    private func determineFreshNoteCreation(notes: [Note], recentNotes: [Note]) -> FreshNoteDecision {
        // Check if always create new is enabled
        if UserDefaults.standard.bool(forKey: "alwaysCreateNewNote") {
            return FreshNoteDecision(createNew: true, reuseExisting: false, existingNote: nil)
        }
        
        // Check time boundary
        guard let lastForegroundDate = UserDefaults.standard.object(forKey: "lastForegroundDate") as? Date else {
            return FreshNoteDecision(createNew: false, reuseExisting: false, existingNote: nil)
        }
        
        let thresholdHours = UserDefaults.standard.double(forKey: "freshNoteThresholdHours")
        let boundaryDate = Calendar.current.date(byAdding: .hour, value: -Int(thresholdHours), to: Date()) ?? Date()
        
        if lastForegroundDate > boundaryDate {
            return FreshNoteDecision(createNew: false, reuseExisting: false, existingNote: nil)
        }
        
        // Check if we should reuse an empty note
        if let mostRecent = recentNotes.first, isNoteEmpty(mostRecent) {
            return FreshNoteDecision(createNew: true, reuseExisting: true, existingNote: mostRecent)
        }
        
        return FreshNoteDecision(createNew: true, reuseExisting: false, existingNote: nil)
    }
    
    private func isNoteEmpty(_ note: Note) -> Bool {
        let content = note.plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty
    }
    
    // MARK: - Settings
    
    private func settingsButton() -> some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gear")
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("alwaysCreateNewNote") private var alwaysCreateNewNote = false
    @AppStorage("freshNoteThresholdHours") private var freshNoteThresholdHours = 4.0
    @AppStorage("magneticScrollingEnabled") private var magneticScrollingEnabled = true
    @AppStorage("newNoteWithBigFont") private var newNoteWithBigFont = true
    @AppStorage("dragToReorderParagraphEnabled") private var dragToReorderParagraphEnabled = false
    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("collapseSidebarInLandscape") private var collapseSidebarInLandscape = false
    @AppStorage("collapseSidebarInPortrait") private var collapseSidebarInPortrait = true
    
    var body: some View {
        Form {
            Section(header: Text("Fresh Note Creation")) {
                Toggle("Always create new note", isOn: $alwaysCreateNewNote)
                
                if !alwaysCreateNewNote {
                    Stepper("Create new note after: \(Int(freshNoteThresholdHours)) hours", 
                           value: $freshNoteThresholdHours, in: 1...24, step: 1.0)
                }
            }
            
            Section(header: Text("Sections")) {
                Toggle("Show pinned section", isOn: Binding(
                    get: { pinnedVisible },
                    set: { newValue in
                        if !newValue {
                            let visibleCount = [pinnedVisible, recentsVisible, historyVisible].map { $0 ? 1 : 0 }.reduce(0, +)
                            if visibleCount <= 1 {
                                return
                            }
                        }
                        pinnedVisible = newValue
                    }
                ))
                Toggle("Show recents section", isOn: Binding(
                    get: { recentsVisible },
                    set: { newValue in
                        if !newValue {
                            let visibleCount = [pinnedVisible, recentsVisible, historyVisible].map { $0 ? 1 : 0 }.reduce(0, +)
                            if visibleCount <= 1 {
                                return
                            }
                        }
                        recentsVisible = newValue
                    }
                ))
                Toggle("Show history section", isOn: Binding(
                    get: { historyVisible },
                    set: { newValue in
                        if !newValue {
                            let visibleCount = [pinnedVisible, recentsVisible, historyVisible].map { $0 ? 1 : 0 }.reduce(0, +)
                            if visibleCount <= 1 {
                                return
                            }
                        }
                        historyVisible = newValue
                    }
                ))
            }
            
            Section(header: Text("Editor")) {
                Toggle("Magnetic scrolling", isOn: $magneticScrollingEnabled)
                Toggle("New notes start with big font", isOn: $newNoteWithBigFont)
                Toggle("Drag to reorder paragraph (WIP)", isOn: $dragToReorderParagraphEnabled)
            }
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                Section(header: Text("Sidebar")) {
                    Toggle("Collapse sidebar in landscape", isOn: $collapseSidebarInLandscape)
                    Toggle("Collapse sidebar in portrait", isOn: $collapseSidebarInPortrait)
                }
            }
        }
        .navigationTitle("Settings")
    }
}


extension Notification.Name {
    static let sidebarStateChanged = Notification.Name("SidebarStateChangedNotification")
}

#Preview {
    ContentView()
}