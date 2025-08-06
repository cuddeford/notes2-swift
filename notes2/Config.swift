//
//  Config.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // The two detents for paragraph spacing
    static let relatedParagraphSpacing: CGFloat = 32
    static let unrelatedParagraphSpacing: CGFloat = 250
    static let titleFontSizeModifier: CGFloat = 0

    static let showRuledLines = false

    @Published var defaultParagraphSpacing: Double {
        didSet { UserDefaults.standard.set(defaultParagraphSpacing, forKey: "defaultParagraphSpacing") }
    }

    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }

    @Published var padding: Double {
        didSet { UserDefaults.standard.set(padding, forKey: "padding") }
    }

    @Published var magneticScrollingEnabled: Bool {
        didSet { UserDefaults.standard.set(magneticScrollingEnabled, forKey: "magneticScrollingEnabled") }
    }

    @Published var dragToReorderParagraphEnabled: Bool {
        didSet { UserDefaults.standard.set(dragToReorderParagraphEnabled, forKey: "dragToReorderParagraphEnabled") }
    }

    @Published var paragraphOverlaysEnabled: Bool {
        didSet { UserDefaults.standard.set(paragraphOverlaysEnabled, forKey: "paragraphOverlaysEnabled") }
    }

    static func registerDefaults() {
        let defaults: [String: Any] = [
            "recentsVisible": true,
            "historyVisible": true,
            "pinnedVisible": true,
            "newNoteWithBigFont": true,
            "magneticScrollingEnabled": false,
            "dragToReorderParagraphEnabled": true,
            "paragraphOverlaysEnabled": true,
            "defaultParagraphSpacing": relatedParagraphSpacing,
            "fontSize": 18.0,
            "padding": 20.0
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    private init() {
        let spacing = UserDefaults.standard.double(forKey: "defaultParagraphSpacing")
        self.defaultParagraphSpacing = spacing

        let size = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = size

        let padding = UserDefaults.standard.double(forKey: "padding")
        self.padding = padding

        self.magneticScrollingEnabled = UserDefaults.standard.object(forKey: "magneticScrollingEnabled") as? Bool ?? false
        self.dragToReorderParagraphEnabled = UserDefaults.standard.object(forKey: "dragToReorderParagraphEnabled") as? Bool ?? false
        self.paragraphOverlaysEnabled = UserDefaults.standard.object(forKey: "paragraphOverlaysEnabled") as? Bool ?? true
    }
}
