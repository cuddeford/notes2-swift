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

    @Published var freshNoteThresholdHours: Int {
        didSet { UserDefaults.standard.set(freshNoteThresholdHours, forKey: "freshNoteThresholdHours") }
    }

    @Published var alwaysCreateNewNote: Bool {
        didSet { UserDefaults.standard.set(alwaysCreateNewNote, forKey: "alwaysCreateNewNote") }
    }

    private init() {
        let spacing = UserDefaults.standard.double(forKey: "defaultParagraphSpacing")
        self.defaultParagraphSpacing = spacing == 0 ? AppSettings.unrelatedParagraphSpacing : spacing

        let size = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = size == 0 ? 18.0 : size

        let padding = UserDefaults.standard.double(forKey: "padding")
        self.padding = padding == 0 ? 20.0 : padding

        self.magneticScrollingEnabled = UserDefaults.standard.object(forKey: "magneticScrollingEnabled") as? Bool ?? false
        self.dragToReorderParagraphEnabled = UserDefaults.standard.object(forKey: "dragToReorderParagraphEnabled") as? Bool ?? false
        
        let threshold = UserDefaults.standard.integer(forKey: "freshNoteThresholdHours")
        self.freshNoteThresholdHours = threshold == 0 ? 6 : threshold
        
        self.alwaysCreateNewNote = UserDefaults.standard.bool(forKey: "alwaysCreateNewNote")
    }
}
