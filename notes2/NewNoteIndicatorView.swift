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
    var isDragging: Bool
    var dragActivationPoint: Double

    var body: some View {
        let willCreateNote = translation.width < -dragActivationPoint
        let backgroundColor = willCreateNote ? Color(.systemGreen) : Color(.systemGray3)
        let height = UIScreen.main.bounds.height

        Ellipse()
            .fill(backgroundColor)
            .frame(width: min(abs(translation.width), dragActivationPoint) * 2.0, height: height)
            .overlay(
                Image(systemName: "square.and.pencil")
                    .font(.largeTitle)
                    .padding()
                    .foregroundColor(willCreateNote ? .white : .black)
                    .onChange(of: willCreateNote) { oldValue, newValue in
                        if oldValue != newValue {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .animation(.spring(), value: willCreateNote)
                ,
                alignment: .leading,
            )
            .opacity(isDragging ? willCreateNote ? 0.9 : 0.5 : 0)
            .animation(.spring(), value: isDragging)
            .position(x: UIScreen.main.bounds.width, y: height / 2.0)
            .animation(.spring(), value: translation.width)
            .transition(.opacity)
    }
}
