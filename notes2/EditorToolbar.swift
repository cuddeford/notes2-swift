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
    @AppStorage("editorToolbarExpanded") private var isExpanded: Bool = true

    var body: some View {
        HStack {
            if isExpanded {
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
                                        .fill(.ultraThinMaterial)
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
                                        .fill(.ultraThinMaterial)
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
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }

                    Spacer()

                    HStack {
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
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onBody()
                        }) {
                            Text("body")
                                .padding(10)
                                .background(
                                    Rectangle()
                                        .fill(.ultraThinMaterial)
                                        .cornerRadius(25)
                                )
                        }
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).animation(.easeInOut(duration: 0.4))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.2).delay(0.2))),
                        removal: .move(edge: .trailing).animation(.easeInOut(duration: 0.4))
                            .combined(with: .opacity.animation(.easeInOut(duration: 0.2)))
                    )
                )
            }

            Spacer() // Always present to push the toggle button to the right

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.easeInOut) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: "chevron.down.circle.fill")
                    .padding(16)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .opacity(isExpanded ? 1 : 0.5)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
        .animation(.easeInOut, value: isExpanded)
    }
}
