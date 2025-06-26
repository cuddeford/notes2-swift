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
                    Section(isExpanded: $pinnedExpanded) {
                        ForEach(pinnedNotes) { note in
                            NavigationLink(value: note) {
                                VStack(alignment: .leading) {
                                    Text(note.firstLine.isEmpty ? "untitled" : note.firstLine)
                                        .font(.headline)
                                        .italic(note.firstLine.isEmpty)
                                        .opacity(note.firstLine.isEmpty ? 0.5 : 1)
                                    Text("\(relativeDate(note.createdAt)) at \(note.createdAt, style: .time)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onLongPressGesture {
                                note.isPinned.toggle()
                                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                                impactMed.impactOccurred()
                            }
                        }
                        .onDelete(perform: deletePinnedNotes)
                        .padding(.vertical, 4)
                    } header: {
                        Text("Pinned")
                    }

                    Section(isExpanded: $recentsExpanded) {
                        ForEach(recentNotes) { note in
                            NavigationLink(value: note) {
                                VStack(alignment: .leading) {
                                    Text(note.firstLine.isEmpty ? "untitled" : note.firstLine)
                                        .font(.headline)
                                        .italic(note.firstLine.isEmpty)
                                        .opacity(note.firstLine.isEmpty ? 0.5 : 1)
                                    // note.createdAt is correct here. DO NOT use note.updatedAt
                                    Text("\(relativeDate(note.createdAt)) at \(note.createdAt, style: .time)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onLongPressGesture {
                                note.isPinned.toggle()
                                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                                impactMed.impactOccurred()
                            }
                        }
                        .onDelete(perform: deleteRecentNotes)
                        .padding(.vertical, 4)
                    } header: {
                        Text("Recent")
                    }

                    DisclosureGroup("History", isExpanded: $historyExpanded) {
                        ForEach(sortedDays, id: \.self) { day in
                            Section(isExpanded: binding(for: day)) {
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
                                    .onLongPressGesture {
                                        note.isPinned.toggle()
                                        let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                                        impactMed.impactOccurred()
                                    }
                                }
                                .onDelete { indexSet in
                                    if let notesForDay = groupedNotes[day] {
                                        for index in indexSet {
                                            let note = notesForDay[index]
                                            context.delete(note)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            } header: {
                                HStack {
                                    Text(formattedDate(day))
                                    Spacer()
                                    Text(relativeDate(day))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
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

                    if let data = UserDefaults.standard.data(forKey: "historicalExpanded") {
                        if let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) {
                            self.historicalExpanded = decoded
                        }
                    }
                }
                .onChange(of: historicalExpanded) { oldValue, newValue in
                    if let encoded = try? JSONEncoder().encode(newValue) {
                        UserDefaults.standard.set(encoded, forKey: "historicalExpanded")
                    }
                }
            }
        } detail: {
            Text("Select a note")
                .foregroundStyle(.secondary)
        }
    }

    func deleteRecentNotes(at offsets: IndexSet) {
        let recentNotes = notes.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(2)
        for index in offsets {
            let note = recentNotes[index]
            context.delete(note)
        }
    }

    func deletePinnedNotes(at offsets: IndexSet) {
        let pinnedNotes = notes.filter { $0.isPinned }.sorted(by: { $0.updatedAt > $1.updatedAt })
        for index in offsets {
            let note = pinnedNotes[index]
            context.delete(note)
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        if date >= startOfWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Last \(formatter.string(from: date))"
        }
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
