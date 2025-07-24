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

    var body: some View {
        VStack {
            Spacer()
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
                .padding(.bottom, keyboard.keyboardHeight)
                .transition(.opacity)
            }
        }
        .animation(.linear(duration: 0.15), value: keyboard.keyboardHeight)
        .edgesIgnoringSafeArea(.bottom)
    }
}
