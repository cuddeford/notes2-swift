//
//  ContentView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

struct Note: Identifiable, Hashable {
    let id: UUID
    let title: String
}

struct ContentView: View {
    @State private var notes = [
        Note(
            id: UUID(uuidString: "7F9E71EF-BD32-4674-82F9-3AAA4C529A07")
                ?? UUID(),
            title: "First Note"
        ),
        Note(
            id: UUID(uuidString: "C2B6D78D-554B-4919-93C5-4B7D52005F92")
                ?? UUID(),
            title: "Second Note"
        ),
    ]
    @State private var selectedNote: Note?

    @State private var path = NavigationPath()

    var body: some View {
        NavigationSplitView {
            NavigationStack(path: $path) {
                List(notes) { note in
                    NavigationLink(value: note) {
                        Text(note.title)
                    }
                }
                .navigationTitle("Notes")
                .navigationDestination(for: Note.self) { note in
                    NoteView(note: note)
                }
                .onAppear {
                    if let idString = UserDefaults.standard.string(
                        forKey: "lastOpenedNoteID"
                    ),
                        let uuid = UUID(uuidString: idString),
                        let note = notes.first(where: { $0.id == uuid })
                    {
                        path = NavigationPath()
                        path.append(note)
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
    let note: Note

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @ObservedObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    init(note: Note) {
        self.note = note
        _noteText = State(initialValue: loadNote(for: note))
    }

    var body: some View {
        ZStack {
            RichTextEditor(
                text: $noteText,
                selectedRange: $selectedRange,
                keyboard: keyboard,
                onCoordinatorReady: { coordinator in
                    self.editorCoordinator = coordinator
                },
            )
//                        .border(Color(.red), width: 2)
            .onChange(of: noteText) { oldValue, newValue in
                saveNote(note, content: newValue)
            }
        }
        .navigationTitle(note.title)
        .toolbar {
            if keyboard.isKeyboardVisible {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIApplication.shared.sendAction(
                            #selector(
                                UIResponder.resignFirstResponder
                            ),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }) {
                        Text("Done")
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            UserDefaults.standard.set(
                note.id.uuidString,
                forKey: "lastOpenedNoteID"
            )
            let savedLocation = UserDefaults.standard.integer(
                forKey: "noteCursorLocation"
            )
            let safeLocation = min(savedLocation, noteText.length)
            selectedRange = NSRange(
                location: safeLocation,
                length: 0
            )
        }
    }
}

#Preview {
    ContentView()
}
