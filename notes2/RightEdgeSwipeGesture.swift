import SwiftUI
import UIKit

struct RightEdgeSwipeGesture: UIViewRepresentable {
    @Binding var gestureState: UIGestureRecognizer.State
    @Binding var translation: CGSize
    @Binding var location: CGPoint
    var onEnded: () -> Void

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
            parent.gestureState = gesture.state
            let translationPoint = gesture.translation(in: gesture.view)
            parent.translation = CGSize(width: translationPoint.x, height: translationPoint.y)

            if gesture.state == .began {
                parent.location = gesture.location(in: gesture.view)
            }

            if gesture.state == .ended {
                // Only trigger onEnded if the swipe was significant and to the left
                if parent.translation.width < -50 {
                    parent.onEnded()
                }
            }
        }
    }
}

extension View {
    func onRightEdgeSwipe(gestureState: Binding<UIGestureRecognizer.State>, translation: Binding<CGSize>, location: Binding<CGPoint>, onEnded: @escaping () -> Void) -> some View {
        self.overlay(RightEdgeSwipeGesture(gestureState: gestureState, translation: translation, location: location, onEnded: onEnded))
    }
}
