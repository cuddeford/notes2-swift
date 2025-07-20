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

    private init() {
        let spacing = UserDefaults.standard.double(forKey: "defaultParagraphSpacing")
        self.defaultParagraphSpacing = spacing == 0 ? AppSettings.unrelatedParagraphSpacing : spacing

        let size = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = size == 0 ? 18.0 : size

        let padding = UserDefaults.standard.double(forKey: "padding")
        self.padding = padding == 0 ? 20.0 : padding
    }
}
