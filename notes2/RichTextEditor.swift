//
//  RichTextEditor.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI

func paragraphRange(for text: NSAttributedString, at location: Int) -> NSRange {
    let string = text.string as NSString
    let length = string.length
    guard length > 0 else { return NSRange(location: 0, length: 0) }
    let safeLocation = min(max(location, 0), length - 1)
    return string.paragraphRange(for: NSRange(location: safeLocation, length: 0))
}

func wordRange(for text: NSAttributedString, at location: Int) -> NSRange {
    let string = text.string as NSString
    let length = string.length
    guard length > 0 else { return NSRange(location: 0, length: 0) }
    let safeLocation = min(max(location, 0), length - 1)
    let range = string.rangeOfWord(at: safeLocation)
    return range
}

extension NSString {
    func rangeOfWord(at location: Int) -> NSRange {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let length = self.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        var start = location
        var end = location

        // Move start to the beginning of the word
        while start > 0 && !separators.contains(UnicodeScalar(character(at: start - 1))!) {
            start -= 1
        }
        // Move end to the end of the word
        while end < length && !separators.contains(UnicodeScalar(character(at: end))!) {
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange

    @StateObject var settings = AppSettings.shared

    var keyboard: KeyboardObserver

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        private var debounceWorkItem: DispatchWorkItem?
        var toolbarHostingController: UIHostingController<EditorToolbar>?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.text = textView.attributedText
                self.centerCursorInTextView()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.selectedRange = textView.selectedRange
                self.updateTypingAttributes()
                if textView.selectedRange.length == 0 {
                    self.centerCursorInTextView()

                    UserDefaults.standard.set(textView.selectedRange.location, forKey: "noteCursorLocation")
                }
            }
        }

        func updateTypingAttributes() {
            guard let textView = textView else { return }
            let loc = max(0, min(textView.selectedRange.location - 1, textView.attributedText.length - 1))
            if textView.attributedText.length > 0 && loc >= 0 {
                let attrs = textView.attributedText.attributes(at: loc, effectiveRange: nil)
                textView.typingAttributes = attrs
            }
        }

        func centerCursorInTextView() {
            return

            guard let textView = textView else { return }
            guard let selectedTextRange = textView.selectedTextRange else { return }

            let caretRect = textView.caretRect(for: selectedTextRange.end)
            let visibleHeight = textView.bounds.height - textView.contentInset.top - textView.contentInset.bottom
            let targetOffsetY = caretRect.midY - visibleHeight * 0.75

            let maxOffsetY = textView.contentSize.height - visibleHeight
            let minOffsetY: CGFloat = 0
            let finalOffsetY = max(minOffsetY, min(targetOffsetY, maxOffsetY))

            // Only scroll if the offset is significantly different (e.g., > 2 points)
            if abs(textView.contentOffset.y - finalOffsetY) > 5 {
                print("RE-CENTERING!")
                textView.setContentOffset(CGPoint(x: 0, y: finalOffsetY), animated: true)
            }
        }

        func printRawString(_ textView: UITextView) {
            print("---")
            textView.attributedText.enumerateAttributes(
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { attrs, range, _ in
                let substring = textView.attributedText.attributedSubstring(from: range).string
                print("\"\(substring)\" has attributes: \(attrs)")
            }
            print("---")
        }

        func toggleAttribute(_ attribute: NoteTextAttribute) {
            let mutable = NSMutableAttributedString(attributedString: parent.text)
            var range = parent.selectedRange

            // For headings, apply to paragraph if no selection
            if (attribute == .title1 || attribute == .title2 || attribute == .body), range.length == 0 {
                range = paragraphRange(for: parent.text, at: range.location)
            }

            // For bold/italic/underline, apply to word if no selection
            if (attribute == .bold || attribute == .italic || attribute == .underline), range.length == 0 {
                range = wordRange(for: parent.text, at: range.location)
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

            parent.text = mutable
            self.updateTypingAttributes()
        }
    }

    var onCoordinatorReady: ((Coordinator) -> Void)? = nil
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        DispatchQueue.main.async {
            self.onCoordinatorReady?(coordinator)
        }

        return coordinator
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(
            top: settings.padding,
            left: settings.padding,
            bottom: 200,
            right: settings.padding
        )
        textView.keyboardDismissMode = .interactive
        textView.font = UIFont.preferredFont(forTextStyle: .title1)
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = settings.paragraphSpacing
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        // --- Add the SwiftUI toolbar as inputAccessoryView ---
        let toolbar = EditorToolbar(
            onBold: { context.coordinator.toggleAttribute(.bold) },
            onItalic: { context.coordinator.toggleAttribute(.italic) },
            onUnderline: { context.coordinator.toggleAttribute(.underline) },
            onTitle1: { context.coordinator.toggleAttribute(.title1) },
            onTitle2: { context.coordinator.toggleAttribute(.title2) },
            onBody: { context.coordinator.toggleAttribute(.body) },
            settings: settings,
            keyboard: keyboard,
        )
        let hostingController = UIHostingController(rootView: toolbar)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60)
        textView.inputAccessoryView = hostingController.view
        context.coordinator.toolbarHostingController = hostingController
        // -----------------------------------------------------

        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != text {
            let mutable = NSMutableAttributedString(attributedString: text)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = settings.paragraphSpacing
            mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutable.length))
            uiView.attributedText = mutable
        }

        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }

        context.coordinator.updateTypingAttributes()

        // Update the toolbar if settings changed
        if let hostingController = context.coordinator.toolbarHostingController {
            hostingController.rootView = EditorToolbar(
                onBold: { context.coordinator.toggleAttribute(.bold) },
                onItalic: { context.coordinator.toggleAttribute(.italic) },
                onUnderline: { context.coordinator.toggleAttribute(.underline) },
                onTitle1: { context.coordinator.toggleAttribute(.title1) },
                onTitle2: { context.coordinator.toggleAttribute(.title2) },
                onBody: { context.coordinator.toggleAttribute(.body) },
                settings: settings,
                keyboard: keyboard,
            )
            hostingController.view.setNeedsLayout()
        }

        // Automatically adjust the text container inset based on keyboard height
        let baseInset: CGFloat = settings.padding
        let extraWhitespace: CGFloat = 200
        let keyboardHeight = keyboard.keyboardHeight

        let bottomInset: CGFloat
        if keyboardHeight > 0 {
            bottomInset = keyboardHeight + baseInset
        } else {
            bottomInset = extraWhitespace
        }

        if uiView.textContainerInset.bottom != bottomInset {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
                uiView.textContainerInset = UIEdgeInsets(
                    top: baseInset,
                    left: baseInset,
                    bottom: bottomInset,
                    right: baseInset,
                )
            }
        }
    }
}
