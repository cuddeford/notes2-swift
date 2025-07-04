
//
//  Paragraph.swift
//  notes2
//
//  Created by Lucio Cuddeford on 04/07/2025.
//

import Foundation
import SwiftUI

struct Paragraph: Identifiable, Equatable {
    let id = UUID()
    var content: NSAttributedString
    var range: NSRange
    var paragraphSpacing: CGFloat = 0.0
    var numberOfLines: Int = 0
    var height: CGFloat = 0.0
    var screenPosition: CGPoint = .zero
}
