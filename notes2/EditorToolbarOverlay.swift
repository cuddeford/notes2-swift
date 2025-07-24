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
        let toolbarBottomPadding = max(keyboard.keyboardHeight - 15, isAtBottom && keyboard.keyboardHeight == 0 ? 40 : 15)
        
        VStack {
            Spacer()
            VStack(spacing: 8) {
                if !isAtBottom {
                    HStack() {
                        Spacer()
                        ScrollToBottomButton(action: onScrollToBottom)
                            .padding(16)
                            .transition(.opacity)
                    }
                }

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
