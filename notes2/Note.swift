
//
//  Note.swift
//  notes2
//
//  Created by Lucio Cuddeford on 01/07/2025.
//

import Foundation
import SwiftData
import SwiftUI // For NSAttributedString

@Model
class Note: Identifiable, Hashable {
    var id: UUID = UUID()
    var content: Data = Data()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var cursorLocation: Int = 0
    var isPinned: Bool = false

    init(id: UUID = UUID(), content: Data = Data(), createdAt: Date = Date(), updatedAt: Date = Date(), cursorLocation: Int = 0, isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cursorLocation = cursorLocation
        self.isPinned = isPinned
    }

    static func == (lhs: Note, rhs: Note) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Note {
    var firstLine: String {
        if let attr = try? NSAttributedString(
            data: self.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            let plain = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstLine = plain.components(separatedBy: .newlines).first {
                let trimmedLine = firstLine.trimmingCharacters(in: .whitespaces)
                let maxLength = 70
                if trimmedLine.count > maxLength {
                    return String(trimmedLine.prefix(maxLength - 3)) + "..."
                } else {
                    return trimmedLine.isEmpty ? "" : trimmedLine
                }
            }
        }

        return ""
    }

    var plain: String {
        if let attr = try? NSAttributedString(
            data: self.content,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        ) {
            return attr.string.isEmpty
                ? ""
                : attr.string
        }

        return ""
    }
}
