//
//  EditorToolbar.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

struct EditorToolbar: View {
    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: () -> Void
    var onTitle1: () -> Void
    var onTitle2: () -> Void
    var onBody: () -> Void
    @ObservedObject var settings: AppSettings
    var keyboard: KeyboardObserver

    var normalisedKeyboardHeight: CGFloat {
//        print(keyboard.keyboardHeight)
        return min(keyboard.keyboardHeight / 396, 1)
    }

    var h: CGFloat {
        print(keyboard.keyboardHeight)
        return keyboard.keyboardHeight
    }

    var body: some View {
        HStack {
            HStack {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onBold()
                }) {
                    Image(systemName: "bold")
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                }

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onItalic()
                }) {
                    Image(systemName: "italic")
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                }

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onUnderline()
                }) {
                    Image(systemName: "underline")
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                }

            }
            .padding(8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )

            Spacer()

            HStack {
                //            Button("-") { settings.paragraphSpacing -= 1 }
                //            Text(String(format: "%.0f", settings.paragraphSpacing))
                //            Button("+") { settings.paragraphSpacing += 1 }
                //            Spacer()
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onTitle1()
                }) {
                    Text("h1")
                        .bold()
                        .padding(16)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                }
//                Button(action: onTitle2) {
//                    Text("h2")
//                        .padding(8)
//                        .background(
//                            Circle()
//                                .fill(Color(.systemGray5))
//                        )
//                }
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onBody()
                }) {
                    Text("body")
                        .padding(10)
                        .background(
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .cornerRadius(25)
                        )
                }
            }
            .padding(8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
        .opacity(h > 60.0 ? 1 : 0)
//        .transition(
//            .asymmetric(
//                insertion: .identity,   // Instantly appears
//                removal: .opacity       // Fades out
//            )
//        )
        .animation(.easeInOut(duration: 0.0001), value: h)
    }
}
