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
                .transition(.scale.combined(with: .opacity))

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
                                    .fill(Color(.systemGray5))
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
                .transition(.scale.combined(with: .opacity))
            }

            Spacer() // Always present to push the toggle button to the right

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.easeInOut) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.left.circle.fill")
                    .font(.title2)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
        .animation(.easeInOut, value: isExpanded)
    }
}
