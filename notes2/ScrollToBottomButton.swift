//
//  ScrollToBottomButton.swift
//  notes2
//
//  Created by Gemini on 24/07/2025.
//

import SwiftUI

struct ScrollToBottomButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: "chevron.down")
                .font(.largeTitle)
                .foregroundColor(.gray)
                .padding()
                .opacity(0.5)
        }
    }
}
