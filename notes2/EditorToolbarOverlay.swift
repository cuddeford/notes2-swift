//
//  EditorToolbarOverlay.swift
//  notes2
//
//  Created by Gemini on 24/07/2025.
//

import SwiftUI

struct EditorToolbarOverlay: View {
    @ObservedObject var keyboard: KeyboardObserver
    @ObservedObject var settings: AppSettings
    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: () -> Void
    var onTitle1: () -> Void
    var onTitle2: () -> Void
    var onBody: () -> Void
    var onScrollToBottom: () -> Void
    var isAtBottom: Bool

    var body: some View {
        let toolbarBottomPadding = max(keyboard.keyboardHeight - 10, 60)

        VStack {
            Spacer()
            VStack() {
                HStack() {
                    Spacer()
                    ScrollToBottomButton(action: onScrollToBottom)
                        .padding(16)
                }
                .opacity(isAtBottom ? 0 : 1)

                if keyboard.keyboardHeight > 0 {
                    EditorToolbar(
                        onBold: onBold,
                        onItalic: onItalic,
                        onUnderline: onUnderline,
                        onTitle1: onTitle1,
                        onTitle2: onTitle2,
                        onBody: onBody,
                        settings: settings
                    )
                    .transition(.opacity)
                }
            }
            .padding(.bottom, toolbarBottomPadding)
        }
        .animation(.linear(duration: 0.15), value: keyboard.keyboardHeight)
        .animation(.linear(duration: 0.15), value: isAtBottom)
        .edgesIgnoringSafeArea(.bottom)
    }
}
