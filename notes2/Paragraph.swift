
//
//  Paragraph.swift
//  notes2
//
//  Created by Lucio Cuddeford on 04/07/2025.
//

import Foundation
import SwiftUI

struct Paragraph: Identifiable, Equatable {
    static func == (lhs: Paragraph, rhs: Paragraph) -> Bool {
        return lhs.id == rhs.id
    }

    var id = UUID()
    var content: NSAttributedString
    var range: NSRange
    var paragraphStyle: NSParagraphStyle = NSParagraphStyle.default
    var numberOfLines: Int = 0
    var height: CGFloat = 0.0
    var screenPosition: CGPoint = .zero
}
