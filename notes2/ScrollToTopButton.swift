//
//  ScrollToTopButton.swift
//  notes2
//
//  Created by Gemini on 01/08/2025.
//

import SwiftUI

struct ScrollToTopButton: View {
    let action: () -> Void
    let isAtTop: Bool
    let canScroll: Bool

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            if (isIOS26) {
                Image(systemName: "arrow.up.to.line.compact")
                .font(.title)
                .foregroundColor(.gray)
                .padding()
                .opacity(0.5)
            } else {
                Image(systemName: "arrow.right.to.line.compact")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()
                    .rotationEffect(.degrees(-90))
                    .opacity(0.5)
            }
        }
        .glassEffectIfAvailable()
        .opacity((isAtTop || !canScroll) ? 0 : 1)
        .animation(.easeInOut, value: isAtTop)
        .animation(.easeInOut, value: canScroll)
    }
}
