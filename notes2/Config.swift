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

    @Published var newNoteIndicatorGestureEnabled: Bool {
        didSet { UserDefaults.standard.set(newNoteIndicatorGestureEnabled, forKey: "newNoteIndicatorGestureEnabled") }
    }

    @Published var lastNoteIndicatorGestureEnabled: Bool {
        didSet { UserDefaults.standard.set(lastNoteIndicatorGestureEnabled, forKey: "lastNoteIndicatorGestureEnabled") }
    }

    @Published var dismissNoteGestureEnabled: Bool {
        didSet { UserDefaults.standard.set(dismissNoteGestureEnabled, forKey: "dismissNoteGestureEnabled") }
    }

    @Published var recentsCount: Int {
        didSet { UserDefaults.standard.set(recentsCount, forKey: "recentsCount") }
    }

    @Published var accentColor: String {
        didSet { UserDefaults.standard.set(accentColor, forKey: "accentColor") }
    }

    static let availableColors: [String: Color] = [
        "Default": Color.accentColor,
        "Blue": .blue,
        "Green": .green,
        "Orange": .orange,
        "Pink": .pink,
        "Purple": .purple,
        "Red": .red,
        "Yellow": .yellow,
        "Custom": Color.accentColor,
    ]

    static func registerDefaults() {
        let defaults: [String: Any] = [
            "recentsVisible": true,
            "historyVisible": true,
            "pinnedVisible": true,
            "newNoteWithBigFont": true,
            "magneticScrollingEnabled": false,
            "dragToReorderParagraphEnabled": true,
            "paragraphOverlaysEnabled": true,
            "newNoteIndicatorGestureEnabled": true,
            "lastNoteIndicatorGestureEnabled": false,
            "dismissNoteGestureEnabled": true,
            "recentsCount": 2,
            "defaultParagraphSpacing": relatedParagraphSpacing,
            "fontSize": 18.0,
            "padding": 20.0,
            "accentColor": "Default",
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
        self.newNoteIndicatorGestureEnabled = UserDefaults.standard.object(forKey: "newNoteIndicatorGestureEnabled") as? Bool ?? true
        self.lastNoteIndicatorGestureEnabled = UserDefaults.standard.object(forKey: "lastNoteIndicatorGestureEnabled") as? Bool ?? true
        self.dismissNoteGestureEnabled = UserDefaults.standard.object(forKey: "dismissNoteGestureEnabled") as? Bool ?? true
        self.recentsCount = UserDefaults.standard.object(forKey: "recentsCount") as? Int ?? 2
        self.accentColor = UserDefaults.standard.string(forKey: "accentColor") ?? "Default"
    }
}

func color(from string: String) -> Color {
    if string == "Custom" {
        if let components = UserDefaults.standard.dictionary(forKey: "customAccentColor"),
           let red = components["red"] as? Double,
           let green = components["green"] as? Double,
           let blue = components["blue"] as? Double,
           let opacity = components["opacity"] as? Double {
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
        }
    }
    return AppSettings.availableColors[string] ?? .accentColor
}
