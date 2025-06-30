//
//  NewNoteIndicatorView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 01/07/2025.
//

import SwiftUI

struct NewNoteIndicatorView: View {
    var translation: CGSize
    var location: CGPoint

    @State private var lastWillCreateNote: Bool = false

    var body: some View {
        let willCreateNote = translation.width < -100
        let backgroundColor = willCreateNote ? Color.green : Color.red

        Text("New Note")
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .position(x: UIScreen.main.bounds.width + translation.width - 60, y: location.y - 50)
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
