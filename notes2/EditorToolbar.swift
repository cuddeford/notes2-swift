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
    var onDismiss: () -> Void
    var onAddParagraph: () -> Void
    var isAtTop: Bool
    var hideKeyboard: () -> Void
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
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                hideKeyboard()
            }) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()
                    .opacity(0.5)
            }

            if isExpanded {
                HStack {
                    Spacer()

                    HStack {
                        Button(action: { buttonAction(action: onTitle1) }) {
                            Image(systemName: "textformat.size")
                                .font(.title)
                                .foregroundColor(.gray)
                                .padding()
                        }

                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onAddParagraph()
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.gray)
                                .padding()
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
                Image(systemName: "chevron.right")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()
                    .opacity(isExpanded ? 1 : 0.5)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal)
        .animation(.easeInOut, value: isExpanded)
        .onAppear(perform: resetTimer)
        .onDisappear(perform: { hideTimer?.invalidate() })
    }
}
