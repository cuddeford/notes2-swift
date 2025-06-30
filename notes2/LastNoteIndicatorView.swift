//
//  LastNoteIndicatorView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 01/07/2025.
//

import SwiftUI
import UIKit

struct LastNoteIndicatorView: View {
    var translation: CGSize
    var location: CGPoint

    @State private var lastWillCreateNote: Bool = false

    var body: some View {
        let willCreateNote = translation.width < -100
        let backgroundColor = willCreateNote ? Color.green : Color.red

        let topInset = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.safeAreaInsets.top ?? 0

        Text("Go to last edited note")
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .position(x: UIScreen.main.bounds.width + translation.width - 60, y: location.y - 150 - topInset)
            .animation(.interactiveSpring(), value: translation)
            .transition(.opacity)
            .onChange(of: willCreateNote) { oldValue, newValue in
                if oldValue != newValue {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}
