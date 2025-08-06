import SwiftUI

struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading) {
            Text(note.firstLine.isEmpty ? "empty" : note.firstLine)
                .font(.headline)
                .italic(note.firstLine.isEmpty)
                .opacity(note.firstLine.isEmpty ? 0.5 : 1)
                .padding(.bottom, 4)

            HStack(spacing: 5) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Text("\(note.createdAt.relativeDate()) at \(note.createdAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                note.isPinned.toggle()
                if note.isPinned {
                    note.pinnedAt = Date()
                } else {
                    note.pinnedAt = nil
                }
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
            } label: {
                Label("Pin", systemImage: note.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(note)
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}
