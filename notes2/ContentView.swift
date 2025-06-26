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
    var content: Data
    var createdAt: Date
    var updatedAt: Date
    var cursorLocation: Int = 0

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

    var body: some View {
        let groupedNotes = Dictionary(grouping: notes) { note in
            Calendar.current.startOfDay(for: note.createdAt)
        }
        let sortedDays = groupedNotes.keys.sorted(by: >)

        NavigationSplitView {
            NavigationStack(path: $path) {
                List {
                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(formattedDate(day))) {
                            ForEach(groupedNotes[day] ?? []) { note in
                                NavigationLink(value: note) {
                                    VStack(alignment: .leading) {
                                        Text(note.firstLine.isEmpty ? "untitled" : note.firstLine)
                                            .font(.headline)
                                            .italic(note.firstLine.isEmpty)
                                            .opacity(note.firstLine.isEmpty ? 0.5 : 1)
                                        Text(note.createdAt, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }.onDelete(perform: deleteNotes)
                }
                .navigationTitle("Notes")
                .navigationDestination(for: Note.self) { note in
                    NoteView(note: note)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            let newNote = Note()
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

    func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            context.delete(note)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NoteView: View {
    @Bindable var note: Note

    @State private var noteText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
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
        }
        .toolbar {
            if keyboard.isKeyboardVisible {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil,
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
