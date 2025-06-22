//
//  Data.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

func saveNote(_ note: NSAttributedString) {
    let data = try? note.data(
        from: NSRange(location: 0, length: note.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
    )
    UserDefaults.standard.set(data, forKey: "noteData")
}

func loadNote() -> NSAttributedString {
    if let data = UserDefaults.standard.data(forKey: "noteData"),
       let note = try? NSAttributedString(
           data: data,
           options: [.documentType: NSAttributedString.DocumentType.rtfd],
           documentAttributes: nil
       ) {
        return note
    }
    return NSAttributedString(string: "")
}
