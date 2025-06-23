//
//  Data.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

func saveNote(_ note: Note, content: NSAttributedString) {
    let data = try? content.data(
        from: NSRange(location: 0, length: content.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
    )
    UserDefaults.standard.set(data, forKey: "noteData-\(note.id.uuidString)")
}

func loadNote(for note: Note) -> NSAttributedString {
    if let data = UserDefaults.standard.data(forKey: "noteData-\(note.id.uuidString)"),
       let content = try? NSAttributedString(
           data: data,
           options: [.documentType: NSAttributedString.DocumentType.rtfd],
           documentAttributes: nil
       ) {
        return content
    }
    return NSAttributedString(string: "")
}
