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
    @Published var keyboardHeight: CGFloat = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willChangeFrame = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> (Bool, CGFloat)? in
                guard let userInfo = notification.userInfo,
                let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                let window = UIApplication.shared
                    .connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow }) else { return nil }
                // Keyboard is visible if its top is less than the window's height
                let isVisible = endFrame.minY < window.bounds.height
                let height = max(0, window.bounds.height - endFrame.minY)
                return (isVisible, height)
            }

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in (false, CGFloat(0)) }

        Publishers.Merge(willChangeFrame, willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible, height in
                withAnimation(.easeInOut(duration: 0.0001)) {
                    self?.isKeyboardVisible = isVisible
                    self?.keyboardHeight = height
                }
            }
            .store(in: &cancellables)
    }
}
