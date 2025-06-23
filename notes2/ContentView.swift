//
//  ContentView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import SwiftData

@Model
class Note: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, content: Data = Data(), createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.content = content

        let now = Date()
        self.createdAt = createdAt ?? now
        self.updatedAt = updatedAt ?? now
    }

    static func == (lhs: Note, rhs: Note) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ContentView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) var notes: [Note]
    @Environment(\.modelContext) private var context

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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            let newNote = Note(title: "new note")
                            context.insert(newNote)
                            path.append(newNote)
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
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
    @Bindable var note: Note

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @ObservedObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared

    init(note: Note) {
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
        }
    }
}

#Preview {
    ContentView()
}
