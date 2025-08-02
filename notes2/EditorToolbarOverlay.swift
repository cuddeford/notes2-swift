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
    var canScroll: Bool
    var isAtTop: Bool
    var onDismiss: () -> Void
    var onNewNote: () -> Void
    var hideKeyboard: () -> Void

    private var isLandscape: Bool {
        UIDevice.current.orientation.isLandscape ||
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation.isLandscape ?? false)
    }

    private var toolbarBottomPadding: CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPad {
            return isLandscape ?
                max(keyboard.keyboardHeight - 120, 0) :
                max(keyboard.keyboardHeight + 10, 80)
        } else {
            return isLandscape ?
                max(keyboard.keyboardHeight - 100, 0) :
                max(keyboard.keyboardHeight - 10, 60)
        }
    }

    var body: some View {
        VStack {
            Spacer()
            VStack() {
                HStack() {
                    Spacer()
                    ScrollToBottomButton(action: onScrollToBottom)
                        .padding(16)
                }
                .opacity((isAtBottom || !canScroll) ? 0 : 1)

                if keyboard.keyboardHeight > 0 {
                    EditorToolbar(
                        onBold: onBold,
                        onItalic: onItalic,
                        onUnderline: onUnderline,
                        onTitle1: onTitle1,
                        onTitle2: onTitle2,
                        onBody: onBody,
                        onDismiss: onDismiss,
                        onNewNote: onNewNote,
                        isAtTop: isAtTop,
                        hideKeyboard: hideKeyboard,
                        settings: settings,
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
