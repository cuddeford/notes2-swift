import SwiftUI

struct DismissNoteIndicatorView: View {
    var translation: CGSize
    var location: CGPoint
    var isDragging: Bool
    var dragActivationPoint: Double

    var body: some View {
        let willDismissNote = translation.width > dragActivationPoint
        let backgroundColor = willDismissNote ? Color(.systemRed) : Color(.systemGray3)
        let height = UIScreen.main.bounds.height

        Ellipse()
            .fill(backgroundColor)
            .frame(width: min(abs(translation.width), dragActivationPoint) * 2.0, height: height)
            .overlay(
                Image(systemName: "xmark")
                    .font(.largeTitle)
                    .padding()
                    .foregroundColor(willDismissNote ? .white : .black)
                    .onChange(of: willDismissNote) { oldValue, newValue in
                        if oldValue != newValue {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .animation(.spring(), value: willDismissNote)
                ,
                alignment: .trailing,
            )
            .opacity(isDragging ? willDismissNote ? 0.9 : 0.5 : 0)
            .animation(.spring(), value: isDragging)
            .position(x: 0, y: height / 2.0)
            .animation(.spring(), value: translation.width)
            .transition(.opacity)
    }
}