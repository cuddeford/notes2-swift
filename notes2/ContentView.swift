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
                    LastNoteIndicatorView(translation: listDragOffset, location: listDragLocation, noteFirstLine: recentNotes.first?.firstLine ?? "untitled")
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

#Preview {
    ContentView()
}
