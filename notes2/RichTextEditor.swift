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

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        private var debounceWorkItem: DispatchWorkItem?

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
        textView.textContainerInset = UIEdgeInsets(top: settings.padding, left: settings.padding, bottom: 125, right: settings.padding)
        textView.keyboardDismissMode = .interactive
        textView.font = UIFont.preferredFont(forTextStyle: .title1)
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
//        textView.borderStyle =
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = settings.paragraphSpacing
        textView.typingAttributes[.paragraphStyle] = paragraphStyle
        
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
    }
}
