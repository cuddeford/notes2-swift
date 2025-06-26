import SwiftUI

struct NoteRow: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.firstLine.isEmpty ? "untitled" : note.firstLine)
                .font(.headline)
                .italic(note.firstLine.isEmpty)
                .opacity(note.firstLine.isEmpty ? 0.5 : 1)
            Text("\(note.createdAt.relativeDate()) at \(note.createdAt, style: .time)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .leading) {
            Button {
                note.isPinned.toggle()
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
            } label: {
                Label("Pin", systemImage: note.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.orange)
        }
    }
}
