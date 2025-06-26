import SwiftUI

struct NoteRow: View {
    @Bindable var note: Note
    @State private var isPressed = false
    var navigateAction: (Note) -> Void

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()) // Make the entire VStack tappable
        .scaleEffect(isPressed ? 1.05 : 1.0)
        .shadow(radius: isPressed ? 10 : 0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }) { // onEnded
            note.isPinned.toggle()
            let impactMed = UIImpactFeedbackGenerator(style: .heavy)
            impactMed.impactOccurred()
            isPressed = false // Reset animation state
        }
        .onTapGesture {
            navigateAction(note)
        }
    }
}
