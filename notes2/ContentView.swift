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
import Combine


struct ContentView: View {
    @Query(sort: \Note.createdAt, order: .reverse) var notes: [Note]
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("recentsVisible") private var recentsVisible = true
    @AppStorage("historyVisible") private var historyVisible = true
    @AppStorage("pinnedVisible") private var pinnedVisible = true
    @AppStorage("recentsExpanded") private var recentsExpanded = true
    @AppStorage("historyExpanded") private var historyExpanded = true
    @AppStorage("pinnedExpanded") private var pinnedExpanded = true
    @State private var historicalExpanded: [String: Bool] = [:]
    @State private var hasRestoredLastOpenedNote = false
    @State private var selectedNoteID: UUID?
    @State private var selectedCompositeID: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @AppStorage("collapseSidebarInLandscape") private var collapseSidebarInLandscape = false
    @AppStorage("collapseSidebarInPortrait") private var collapseSidebarInPortrait = true
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

    private var isPortrait: Bool {
        UIDevice.current.orientation.isPortrait ||
        UIDevice.current.orientation == .unknown ||
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation.isPortrait ?? true)
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
            ZStack {
                List(selection: $selectedCompositeID) {
                    if !searchText.isEmpty {
                        if filteredNotes.isEmpty {
                            Section {
                                Text("No notes found matching \"​\(searchText)\"")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            }
                        } else {
                            Section(header: Text("Search Results")) {
                                ForEach(filteredNotes) { note in
                                    NoteRow(note: note)
                                        .tag("search-\(note.id)")
                                }
                            }
                        }
                    } else {
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
                            selectedCompositeID = "recents-\(newNote.id)"
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("New note")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                Toggle("Collapse sidebar in landscape", isOn: $collapseSidebarInLandscape)
                                Toggle("Collapse sidebar in portrait", isOn: $collapseSidebarInPortrait)
                                Divider()
                            }
                            Toggle("Show pinned section", isOn: Binding(
                                get: { pinnedVisible },
                                set: { newValue in
                                    if !newValue {
                                        let visibleCount = [pinnedVisible, recentsVisible, historyVisible].map { $0 ? 1 : 0 }.reduce(0, +)
                                        if visibleCount <= 1 {
                                            return // Don't allow hiding the last visible section
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
                                            return // Don't allow hiding the last visible section
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
                                            return // Don't allow hiding the last visible section
                                        }
                                    }
                                    historyVisible = newValue
                                }
                            ))
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
                            Image(systemName: "gear")
                        }
                    }
                }
                .onChange(of: historicalExpanded) { oldValue, newValue in
                    if let encoded = try? JSONEncoder().encode(newValue) {
                        UserDefaults.standard.set(encoded, forKey: "historicalExpanded")
                    }
                }
                .onAppear {
                    guard !hasRestoredLastOpenedNote else { return }
                    hasRestoredLastOpenedNote = true

                    if let idString = UserDefaults.standard.string(forKey: "lastOpenedNoteID"),
                       let uuid = UUID(uuidString: idString),
                       let note = notes.first(where: { $0.id == uuid }) {
                        selectedNoteID = note.id

                        // Set the composite selection ID based on which section the note is in
                        if pinnedNotes.contains(where: { $0.id == uuid }) {
                            selectedCompositeID = "pinned-\(uuid)"
                        } else if recentNotes.contains(where: { $0.id == uuid }) {
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
                .overlay {
                    if isListDragging {
                        let isUntitled = recentNotes.first?.firstLine.isEmpty ?? true
                        LastNoteIndicatorView(translation: listDragOffset, location: listDragLocation, noteFirstLine: isUntitled ? "untitled" : recentNotes.first!.firstLine, isUntitled: isUntitled)
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
                                    selectedCompositeID = "recents-\(lastEdited.id)"
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
            }
        } detail: {
            if let selectedNoteID {
                if let note = notes.first(where: { $0.id == selectedNoteID }) {
                    NoteView(note: note, selectedNoteID: $selectedNoteID)
                        .id(selectedNoteID)
                        .environment(\.modelContext, context)
                } else {
                    Text("Loading note...")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a note")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedNoteID) { oldValue, newValue in
            if newValue != nil && horizontalSizeClass == .compact {
                withAnimation(.easeInOut(duration: 0.2)) {
                    columnVisibility = .detailOnly
                }
            }
        }
        .onChange(of: selectedCompositeID) { oldValue, newValue in
            // Extract the actual note ID from composite identifier
            if let compositeID = newValue {
                let parts = compositeID.split(separator: "-", maxSplits: 1)
                if parts.count > 1, let noteID = UUID(uuidString: String(parts[1])) {
                    selectedNoteID = noteID
                }
            } else {
                selectedNoteID = nil
            }
        }
        .onChange(of: selectedNoteID) { oldValue, newValue in
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        if (isPortrait && collapseSidebarInPortrait) || (!isPortrait && collapseSidebarInLandscape) {
                            columnVisibility = .detailOnly
                        }
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        columnVisibility = .automatic
                    }
                }
            }

            // Trigger reflow when note selection changes
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .sidebarStateChanged,
                    object: nil,
                    userInfo: ["trigger": "noteSelectionChanged"]
                )
            }
        }
        .onChange(of: columnVisibility) { oldValue, newValue in
            // Broadcast sidebar state change for text reflow
            NotificationCenter.default.post(
                name: .sidebarStateChanged,
                object: nil,
                userInfo: ["visibility": newValue, "oldValue": oldValue]
            )
        }
    }
}

#Preview {
    ContentView()
}

extension Notification.Name {
    static let sidebarStateChanged = Notification.Name("SidebarStateChangedNotification")
}
