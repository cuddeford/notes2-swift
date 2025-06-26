
import SwiftUI
import UIKit

struct RightEdgeSwipeGesture: UIViewRepresentable {
    var onSwipe: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let gesture = UIScreenEdgePanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleSwipe))
        gesture.edges = .right
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: RightEdgeSwipeGesture

        init(_ parent: RightEdgeSwipeGesture) {
            self.parent = parent
        }

        @objc func handleSwipe(gesture: UIScreenEdgePanGestureRecognizer) {
            if gesture.state == .ended {
                parent.onSwipe()
            }
        }
    }
}

extension View {
    func onRightEdgeSwipe(perform action: @escaping () -> Void) -> some View {
        self.overlay(RightEdgeSwipeGesture(onSwipe: action))
    }
}
