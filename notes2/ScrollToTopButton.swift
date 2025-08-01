//
//  ScrollToTopButton.swift
//  notes2
//
//  Created by Gemini on 01/08/2025.
//

import SwiftUI

struct ScrollToTopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: "chevron.right")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .padding()
                .opacity(0.5)
                .rotationEffect(.degrees(-90))
        }
    }
}
