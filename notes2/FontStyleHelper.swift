//
//  FontStyleHelper.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import UIKit

enum NoteTextStyle {
    case body
    case title1
    case title2
}

extension UIFont {
    static func noteStyle(_ style: NoteTextStyle, traits: UIFontDescriptor.SymbolicTraits = []) -> UIFont {
        let baseFont: UIFont
        switch style {
        case .body:
            baseFont = UIFont.preferredFont(forTextStyle: .body)
        case .title1:
            baseFont = UIFont.preferredFont(forTextStyle: .title1)
        case .title2:
            baseFont = UIFont.preferredFont(forTextStyle: .title2)
        }
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: baseFont.pointSize)
        }
        return baseFont
    }

    func withToggledTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }
        if let descriptor = fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: pointSize)
        }
        return self
    }
}
