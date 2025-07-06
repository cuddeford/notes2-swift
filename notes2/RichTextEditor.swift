//
//  RichTextEditor.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import Combine

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

enum NoteTextAttribute {
    case bold
    case italic
    case underline
    case title1
    case title2
    case body
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    var note: Note

    @StateObject var settings = AppSettings.shared

    var keyboard: KeyboardObserver
    var onCoordinatorReady: ((Coordinator) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(
            top: settings.padding,
            left: settings.padding,
            bottom: settings.padding,
            right: settings.padding
        )
        textView.keyboardDismissMode = .interactive
        textView.font = UIFont.preferredFont(forTextStyle: .title1)
        textView.delegate = context.coordinator
        textView.allowsEditingTextAttributes = true
        
        let ruledView = RuledView(frame: .zero)
        ruledView.textView = textView
        textView.backgroundColor = .clear
        textView.addSubview(ruledView)
        textView.sendSubviewToBack(ruledView)
        context.coordinator.ruledView = ruledView

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = settings.defaultParagraphSpacing
        paragraphStyle.minimumLineHeight = textView.font!.lineHeight
        paragraphStyle.maximumLineHeight = textView.font!.lineHeight
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        // Apply default title style if the text view is empty
        if textView.attributedText.length == 0 {
            let defaultFont = UIFont.noteStyle(.title1, traits: .traitBold)
            textView.typingAttributes[.font] = defaultFont
        }

        // --- Add the SwiftUI toolbar as inputAccessoryView ---
        let toolbar = EditorToolbar(
            onBold: { context.coordinator.toggleAttribute(.bold) },
            onItalic: { context.coordinator.toggleAttribute(.italic) },
            onUnderline: { context.coordinator.toggleAttribute(.underline) },
            onTitle1: { context.coordinator.toggleAttribute(.title1) },
            onTitle2: { context.coordinator.toggleAttribute(.title2) },
            onBody: { context.coordinator.toggleAttribute(.body) },
            settings: settings
        )
        let hostingController = UIHostingController(rootView: toolbar)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60)
        textView.inputAccessoryView = hostingController.view
        context.coordinator.toolbarHostingController = hostingController
        // -----------------------------------------------------

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinchGesture(_:)))
        textView.addGestureRecognizer(pinchGesture)

        context.coordinator.textView = textView
        context.coordinator.textContainerInset = textView.textContainerInset
        context.coordinator.textViewWidth = textView.bounds.width
        DispatchQueue.main.async { // Ensure UI updates happen on the main thread
            textView.becomeFirstResponder()
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if the attributed text has actually changed to avoid infinite loops
        if uiView.attributedText != text {
            uiView.attributedText = text
            context.coordinator.parseAttributedText(text)
        }

        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }

        context.coordinator.updateRuledViewFrame()

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
                settings: settings
            )
            hostingController.view.setNeedsLayout()
        }

        // --- Typewriter Scrolling Insets ---
        let baseInset: CGFloat = settings.padding
        let keyboardHeight = keyboard.keyboardHeight

        // Adjust contentInset to make space for the keyboard and typewriter effect
        let bottomContentInset: CGFloat
        if keyboardHeight > 0 {
            // When the keyboard is visible, the bottom inset should be large enough to allow
            // scrolling the text way up, leaving a large blank area below.
            // This makes it feel like the text view is scrolling "over" the keyboard.
            bottomContentInset = keyboardHeight - uiView.safeAreaInsets.bottom + baseInset
        } else {
            // When the keyboard is hidden, we don't need a huge inset.
            bottomContentInset = baseInset
        }

        let newContentInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomContentInset,
            right: 0
        )

        if uiView.contentInset != newContentInsets {
            uiView.contentInset = newContentInsets
            // Also adjust the scroll indicators to match
            uiView.scrollIndicatorInsets = newContentInsets
        }
        context.coordinator.textViewWidth = uiView.bounds.width
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        onCoordinatorReady?(coordinator)
        return coordinator
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?
        weak var ruledView: RuledView?
        private var debounceWorkItem: DispatchWorkItem?
        var toolbarHostingController: UIHostingController<EditorToolbar>?
        private var initialSpacing: CGFloat?
        private var affectedParagraphRange: NSRange?
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private let spacingDetents: [CGFloat] = [2, 4, 8, 12, 18, 24, 36, 48, 60, 72]
        private var lastDetentIndex: Int = -1

        @Published var paragraphs: [Paragraph] = []
        @Published var textContainerInset: UIEdgeInsets = .zero
        @Published var contentOffset: CGPoint = .zero
        @Published var textViewWidth: CGFloat = 0

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        func parseAttributedText(_ attributedText: NSAttributedString) {
            var newParagraphs: [Paragraph] = []
            let fullRange = NSRange(location: 0, length: attributedText.length)
            var currentIndex = 0

            while currentIndex < fullRange.length {
                let paragraphNSRange = (attributedText.string as NSString).paragraphRange(for: NSRange(location: currentIndex, length: 0))
                let paragraphContent = attributedText.attributedSubstring(from: paragraphNSRange)

                let currentAttributes = attributedText.attributes(at: paragraphNSRange.location, effectiveRange: nil)
                let paragraphStyle = (currentAttributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default

                newParagraphs.append(Paragraph(content: paragraphContent, range: paragraphNSRange, paragraphStyle: paragraphStyle))
                currentIndex = NSMaxRange(paragraphNSRange)
            }
            self.paragraphs = newParagraphs
            updateParagraphSpatialProperties()
        }

        func updateParagraphSpatialProperties() {
            guard let textView = textView else { return }
            var updatedParagraphs = [Paragraph]()
            var currentYOffset: CGFloat = 0

            for var paragraph in paragraphs {
                let rect = textView.layoutManager.boundingRect(forGlyphRange: paragraph.range, in: textView.textContainer)
                paragraph.height = rect.height
                paragraph.numberOfLines = Int(rect.height / textView.font!.lineHeight) // Approximation
                paragraph.screenPosition = CGPoint(x: rect.origin.x, y: rect.origin.y)

                updatedParagraphs.append(paragraph)
            }
            self.paragraphs = updatedParagraphs
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateParagraphSpatialProperties()
            self.contentOffset = scrollView.contentOffset
            ruledView?.setNeedsDisplay()
        }

        func updateRuledViewFrame() {
            guard let textView = textView, let ruledView = ruledView else { return }
            let contentSize = textView.contentSize
            ruledView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
            ruledView.setNeedsDisplay()
        }

        private func reconstructAttributedText() -> NSAttributedString {
            let mutableAttributedText = NSMutableAttributedString()
            for paragraph in paragraphs {
                let paragraphContent = NSMutableAttributedString(attributedString: paragraph.content)
                paragraphContent.addAttribute(.paragraphStyle, value: paragraph.paragraphStyle, range: NSRange(location: 0, length: paragraphContent.length))
                mutableAttributedText.append(paragraphContent)
            }
            return mutableAttributedText
        }

        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            guard let textView = textView else { return }

            if gesture.state == .began {
                let location = gesture.location(in: textView)
                let characterIndex = textView.layoutManager.characterIndex(for: location, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

                if characterIndex < textView.textStorage.length {
                    let range = paragraphRange(for: textView.attributedText, at: characterIndex)
                    self.affectedParagraphRange = range

                    if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                        self.initialSpacing = paragraphs[index].paragraphStyle.paragraphSpacing
                    } else {
                        self.initialSpacing = parent.settings.defaultParagraphSpacing // Default
                    }
                }
                gesture.scale = 1.0
                hapticGenerator.prepare()

            } else if gesture.state == .changed {
                guard let initialSpacing = initialSpacing, let range = affectedParagraphRange else { return }

                // Calculate a target spacing based on the gesture's scale
                let targetSpacing = initialSpacing * gesture.scale

                // Find the detent closest to the target spacing
                guard let closestDetent = spacingDetents.min(by: { abs($0 - targetSpacing) < abs($1 - targetSpacing) }) else { return }

                if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                    let currentParagraphStyle = paragraphs[index].paragraphStyle
                    if currentParagraphStyle.paragraphSpacing != closestDetent {
                        print("Paragraph spacing: \(closestDetent)")
                        let newParagraphStyle = NSMutableParagraphStyle()
                        newParagraphStyle.setParagraphStyle(currentParagraphStyle)
                        newParagraphStyle.paragraphSpacing = closestDetent
                        paragraphs[index].paragraphStyle = newParagraphStyle

                        // Update the attributed text and the parent binding
                        let updatedText = self.reconstructAttributedText()
                        textView.attributedText = updatedText
                        self.parent.text = updatedText

                        // Animate the change (if any visual properties are animated)
                        UIView.animate(withDuration: 0.1) {
                            // No direct textStorage editing here, layout will happen naturally
                        }

                        // Fire haptic feedback
                        hapticGenerator.impactOccurred()
                        hapticGenerator.prepare()
                    }
                }

            } else if gesture.state == .ended || gesture.state == .cancelled {
                // Update the binding
                parent.text = reconstructAttributedText()
                // Reset state
                initialSpacing = nil
                affectedParagraphRange = nil
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.text = textView.attributedText
                self.parseAttributedText(textView.attributedText)
                self.centerCursorInTextView()
                self.updateRuledViewFrame()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.selectedRange = textView.selectedRange
                self.updateTypingAttributes()
                if textView.selectedRange.length == 0 {
                    self.parent.note.cursorLocation = textView.selectedRange.location
                }
                self.centerCursorInTextView()
            }
        }

        func updateTypingAttributes() {
            guard let textView = textView else { return }
            let loc = max(0, min(textView.selectedRange.location - 1, textView.attributedText.length - 1))
            if textView.attributedText.length > 0 && loc >= 0 {
                var attrs = textView.attributedText.attributes(at: loc, effectiveRange: nil)
                // Ensure paragraph style has correct line heights based on the font
                if let font = attrs[.font] as? UIFont {
                    let paragraphStyle = (attrs[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    paragraphStyle.minimumLineHeight = font.lineHeight
                    paragraphStyle.maximumLineHeight = font.lineHeight
                    attrs[.paragraphStyle] = paragraphStyle
                }
                textView.typingAttributes = attrs
            }
        }

        func centerCursorInTextView() {
            guard let textView = textView, let selectedTextRange = textView.selectedTextRange, textView.hasText else { return }

            let caretRect = textView.caretRect(for: selectedTextRange.end)
            // A caret rect can be infinite if the view is not yet in the hierarchy or has zero size.
            if caretRect.isInfinite || caretRect.isNull { return }

            // The visible portion of the text view, excluding insets
            let visibleHeight = textView.bounds.height - textView.textContainerInset.top - textView.textContainerInset.bottom
            if visibleHeight <= 0 { return }

            // The Y position of the caret relative to the top of the entire content
            let caretY = caretRect.midY

            // The Y position of the top of the visible text area, relative to the content.
            let visibleTopY = textView.contentOffset.y

            // The caret's position relative to the visible frame (ignoring insets for a moment)
            let caretYInFrame = caretY - visibleTopY

            // The "activation point" for typewriter scrolling
            // This point is relative to the frame's top.
            let activationPoint = textView.textContainerInset.top + (visibleHeight)

            // Only scroll if the caret has moved past the activation point
            if caretYInFrame > activationPoint {
                // We want to scroll the text view so that the caret is positioned AT the activation point.
                // The amount to scroll is the difference between the caret's current position and where we want it to be.
                let scrollAmount = caretYInFrame - activationPoint
                let newContentOffsetY = textView.contentOffset.y + scrollAmount

                // Clamp to valid range
                let maxOffsetY = textView.contentSize.height - textView.bounds.height + textView.textContainerInset.bottom
                let minOffsetY = -textView.textContainerInset.top
                let finalOffsetY = max(minOffsetY, min(newContentOffsetY, maxOffsetY))

                // Only animate if the change is non-trivial
                if abs(textView.contentOffset.y - finalOffsetY) > 1 {
                    // Using a very short animation avoids a jarring jump but is faster than the default.
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
                        textView.setContentOffset(CGPoint(x: 0, y: finalOffsetY), animated: false)
                    }, completion: nil)
                }
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

            // If text is empty, apply to typingAttributes instead
            if mutable.length == 0, let textView = self.textView {
                var attrs = textView.typingAttributes

                switch attribute {
                case .bold, .italic:
                    let trait: UIFontDescriptor.SymbolicTraits = (attribute == .bold) ? .traitBold : .traitItalic
                    let currentFont = (attrs[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
                    let newFont = currentFont.withToggledTrait(trait)
                    attrs[.font] = newFont

                case .underline:
                    let isUnderlined = (attrs[.underlineStyle] as? Int ?? 0) != 0
                    attrs[.underlineStyle] = isUnderlined ? 0 : NSUnderlineStyle.single.rawValue

                case .title1, .title2, .body:
                    let targetStyle: NoteTextStyle
                    switch attribute {
                    case .title1: targetStyle = .title1
                    case .title2: targetStyle = .title2
                    case .body: targetStyle = .body
                    default: targetStyle = .body
                    }
                    var traits: UIFontDescriptor.SymbolicTraits = []
                    if targetStyle == .title1 {
                        traits.insert(.traitBold)
                    }
                    let newFont = UIFont.noteStyle(targetStyle, traits: traits)
                    attrs[.font] = newFont
                }

                textView.typingAttributes = attrs
                return
            }

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
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    let newFont: UIFont
                    if isAlreadyStyle {
                        // Toggle off: revert to body
                        traits.remove(.traitBold)
                        newFont = UIFont.noteStyle(.body, traits: traits)
                    } else {
                        // Toggle on: set to target style
                        if targetStyle == .title1 {
                            traits.insert(.traitBold)
                        }
                        newFont = UIFont.noteStyle(targetStyle, traits: traits)
                    }
                    mutable.addAttribute(.font, value: newFont, range: subrange)

                    // Apply paragraph style with correct line height
                    let paragraphStyle = (mutable.attribute(.paragraphStyle, at: subrange.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                    paragraphStyle.minimumLineHeight = newFont.lineHeight
                    paragraphStyle.maximumLineHeight = newFont.lineHeight
                    mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: subrange)
                }
            }

            parent.text = mutable
            self.parseAttributedText(mutable)
            self.updateTypingAttributes()
        }
    }
}
