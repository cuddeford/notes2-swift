//
//  KeyboardObserver.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import Combine

class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                withAnimation(.easeInOut(duration: 0.5)) {
                    self?.isKeyboardVisible = isVisible
                }
            }
            .store(in: &cancellables)
    }
}
