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
    @State private var hideTimer: Timer?

    private func resetTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            withAnimation(.easeInOut) {
                isExpanded = false
            }
        }
    }

    private func buttonAction(action: @escaping () -> Void) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        action()
        resetTimer()
    }

    var body: some View {
        HStack {
            if isExpanded {
                HStack {
                    HStack {
                        Button(action: { buttonAction(action: onBold) }) {
                            Image(systemName: "bold")
                                .padding(16)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }

                        Button(action: { buttonAction(action: onItalic) }) {
                            Image(systemName: "italic")
                                .padding(16)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }

                        Button(action: { buttonAction(action: onUnderline) }) {
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
                        Button(action: { buttonAction(action: onTitle1) }) {
                            Text("h1")
                                .bold()
                                .padding(16)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        Button(action: { buttonAction(action: onBody) }) {
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
                if isExpanded {
                    resetTimer()
                } else {
                    hideTimer?.invalidate()
                }
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .padding(16)
                    .foregroundColor(.accentColor)
                    .opacity(isExpanded ? 1 : 0.5)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
        .animation(.easeInOut, value: isExpanded)
        .onAppear(perform: resetTimer)
        .onDisappear(perform: { hideTimer?.invalidate() })
    }
}
