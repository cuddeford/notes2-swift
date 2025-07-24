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
        Button(action: action) {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .border(Color.yellow, width: 1)
                .padding(16)
                .foregroundColor(.accentColor)
                .border(Color.green, width: 1)
        }
        .border(Color.red, width: 1)
    }
}
