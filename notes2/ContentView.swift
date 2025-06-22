//
//  ContentView.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

enum NoteTextAttribute {
    case bold
    case italic
    case underline
    case title1
    case title2
    case body
}

struct ContentView: View {
    @State private var noteText = loadNote()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var editorCoordinator: RichTextEditor.Coordinator?
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject var settings = AppSettings.shared
    @State private var name = ""
    
    var body: some View {
        ZStack {
            RichTextEditor(text: $noteText, selectedRange: $selectedRange, onCoordinatorReady: { coordinator in
                self.editorCoordinator = coordinator
            })
//            .border(Color(.red), width: 2)
            .onChange(of: noteText) { oldValue, newValue in
                saveNote(newValue)
            }
            
            if keyboard.isKeyboardVisible {
                HStack {
                    HStack {
                        Button(action: { toggleAttribute(.bold) }) { Image(systemName: "bold") }
                        Button(action: { toggleAttribute(.italic) }) { Image(systemName: "italic") }
                        Button(action: { toggleAttribute(.underline) }) { Image(systemName: "underline") }
                        Spacer()
                        Button("-") { settings.paragraphSpacing -= 1 }
                        Text(String(settings.paragraphSpacing))
                        Button("+") { settings.paragraphSpacing += 1 }
                        Spacer()
                        Button(action: { toggleAttribute(.title1) }) { Text("h1") }
                        Button(action: { toggleAttribute(.title2) }) { Text("h2") }
                        Button(action: { toggleAttribute(.body) }) { Text("body") }
                    }
                    .padding()
                    .background(Color(hue: 1.0, saturation: 0.0, brightness: 0.942))
                    .cornerRadius(25)
                    .transition(
                        .asymmetric(
                            insertion: .push(from: .bottom),
                            removal: .push(from: .top),
                        )
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let savedLocation = UserDefaults.standard.integer(forKey: "noteCursorLocation")
            let safeLocation = min(savedLocation, noteText.length)
            selectedRange = NSRange(location: safeLocation, length: 0)
        }
    }
    
    func toggleAttribute(_ attribute: NoteTextAttribute) {
        let mutable = NSMutableAttributedString(attributedString: noteText)
        var range = selectedRange

        // For headings, apply to paragraph if no selection
        if (attribute == .title1 || attribute == .title2 || attribute == .body), range.length == 0 {
            range = paragraphRange(for: noteText, at: range.location)
        }

        // For bold/italic/underline, apply to word if no selection
        if (attribute == .bold || attribute == .italic || attribute == .underline), range.length == 0 {
            range = wordRange(for: noteText, at: range.location)
        }

        guard range.length > 0 else { return }

        switch attribute {
        case .bold, .italic:
            let trait: UIFontDescriptor.SymbolicTraits = (attribute == .bold) ? .traitBold : .traitItalic
            mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .title1)
                let newFont = currentFont.withToggledTrait(trait)
                mutable.addAttribute(.font, value: newFont, range: subrange)
            }

        case .underline:
            var isUnderlined = false
            mutable.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, stop in
                if let style = value as? Int, style != 0 {
                    isUnderlined = true
                    stop.pointee = true
                }
            }
            let newStyle = isUnderlined ? 0 : NSUnderlineStyle.single.rawValue
            mutable.addAttribute(.underlineStyle, value: newStyle, range: range)

        case .title1, .title2, .body:
            let targetStyle: NoteTextStyle
            switch attribute {
            case .title1: targetStyle = .title1
            case .title2: targetStyle = .title2
            case .body: targetStyle = .body
            default: targetStyle = .body
            }

            // Check if all selected text is already the target style
            var isAlreadyStyle = true
            mutable.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
                let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .title1)
                let expectedFont = UIFont.noteStyle(targetStyle, traits: currentFont.fontDescriptor.symbolicTraits)
                if currentFont.pointSize != expectedFont.pointSize {
                    isAlreadyStyle = false
                    stop.pointee = true
                }
            }

            mutable.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let currentFont = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .title1)
                let traits = currentFont.fontDescriptor.symbolicTraits
                let newFont: UIFont
                if isAlreadyStyle {
                    // Toggle off: revert to body
                    newFont = UIFont.noteStyle(.body, traits: traits)
                } else {
                    // Toggle on: set to target style
                    newFont = UIFont.noteStyle(targetStyle, traits: traits)
                }
                mutable.addAttribute(.font, value: newFont, range: subrange)
            }
        }

        noteText = mutable
        editorCoordinator?.updateTypingAttributes()
    }
}

extension View {
    @ViewBuilder
    func conditionalPadding(_ edges: Edge.Set, _ condition: Bool) -> some View {
        if condition {
            self.padding(edges)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}
