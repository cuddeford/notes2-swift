//
//  RichTextEditor.swift
//  notes2
//
//  Created by Lucio Cuddeford on 22/06/2025.
//

import SwiftUI
import Combine
import QuartzCore
import UIKit

enum NoteTextAttribute {
    case bold
    case italic
    case underline
    case title1
    case title2
    case body
}

struct RichTextEditor: UIViewRepresentable {
    typealias UIViewType = CustomTextView
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    var note: Note

    @StateObject var settings = AppSettings.shared

    var keyboard: KeyboardObserver
    var onCoordinatorReady: ((Coordinator) -> Void)? = nil

    @Binding var isAtBottom: Bool
    @Binding var canScroll: Bool

    func makeUIView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
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
        textView.coordinator = context.coordinator
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
            let defaultParagraphStyle = NSMutableParagraphStyle()
            defaultParagraphStyle.paragraphSpacing = settings.defaultParagraphSpacing
            defaultParagraphStyle.minimumLineHeight = defaultFont.lineHeight
            defaultParagraphStyle.maximumLineHeight = defaultFont.lineHeight

            let initialAttributes: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .paragraphStyle: defaultParagraphStyle,
                .foregroundColor: UIColor.label
            ]
            textView.attributedText = NSAttributedString(string: "", attributes: initialAttributes)
            // Also set typing attributes for consistency when user starts typing
            textView.typingAttributes = initialAttributes
        }



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

    func updateUIView(_ uiView: CustomTextView, context: Context) {
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
            bottom: bottomContentInset + 60,
            right: 0
        )

        if uiView.contentInset != newContentInsets {
            UIView.animate(withDuration: 0.25) { // Use a standard animation duration
                uiView.contentInset = newContentInsets
                // Also adjust the scroll indicators to match
                uiView.scrollIndicatorInsets = newContentInsets
            }
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

        private var initialSpacing: CGFloat?
        private var affectedParagraphRange: NSRange?
        private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
        private let completionHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        // Detents for paragraph spacing adjustments
        // min is for related paragraphs, max is for unrelated paragraphs
        private let spacingDetents: [CGFloat] = [AppSettings.relatedParagraphSpacing, AppSettings.unrelatedParagraphSpacing]
        private let animationDuration: CFTimeInterval = 0.5
        private var lastDetentIndex: Int = -1
        private var lastClosestDetent: CGFloat?
        private var wasAtLimit: Bool = false
        private var startedAtLimit: Bool = false
        private var initialLimitValue: CGFloat?
        private var hasTriggeredLightHaptic: Bool = false
        private var activeAnimations: [NSRange: ActiveAnimation] = [:]
        private var lastParagraphCount: Int = 0
        var activePinchedPairs: [NSRange: (indices: [Int], timestamp: CFTimeInterval)] = [:]
        private var pinchedParagraphIndices: [Int] = []

        @Published var paragraphs: [Paragraph] = []
        @Published var textContainerInset: UIEdgeInsets = .zero
        @Published var contentOffset: CGPoint = .zero
        @Published var textViewWidth: CGFloat = 0
        @Published var currentDetent: CGFloat?

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        func parseAttributedText(_ attributedText: NSAttributedString) {
            var newParagraphs: [Paragraph] = []
            let string = attributedText.string

            if attributedText.length == 0 {
                let emptyRange = NSRange(location: 0, length: 0)
                let emptyAttributes: [NSAttributedString.Key: Any] = textView?.typingAttributes ?? [:]
                let emptyParagraphStyle = (emptyAttributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default
                newParagraphs.append(Paragraph(content: NSAttributedString(string: ""), range: emptyRange, paragraphStyle: emptyParagraphStyle))
            } else {
                let lines = string.components(separatedBy: "\n")
                var currentLocation = 0

                for (index, line) in lines.enumerated() {
                    let isLastLine = index == lines.count - 1
                    let lineLength = line.utf16.count
                    let paragraphLength = isLastLine ? lineLength : lineLength + 1
                    let paragraphRange = NSRange(location: currentLocation, length: paragraphLength)

                    guard paragraphRange.location + paragraphRange.length <= attributedText.length else {
                        continue
                    }

                    let paragraphContent = attributedText.attributedSubstring(from: paragraphRange)
                    let locationForAttributes = max(0, min(paragraphRange.location, attributedText.length - 1))
                    let currentAttributes = attributedText.attributes(at: locationForAttributes, effectiveRange: nil)
                    let paragraphStyle = (currentAttributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle.default

                    newParagraphs.append(Paragraph(content: paragraphContent, range: paragraphRange, paragraphStyle: paragraphStyle))
                    currentLocation += paragraphLength
                }
            }

            self.paragraphs = newParagraphs
            self.lastParagraphCount = newParagraphs.count
            updateParagraphSpatialProperties()
            if let tv = textView {
                ruledView?.updateAllParagraphOverlays(
                    paragraphs: self.paragraphs,
                    textView: tv,
                    activePinchedPairs: activePinchedPairs,
                    currentGestureDetent: nil,
                    currentGestureRange: nil,
                )
            }
        }

        func updateParagraphSpatialProperties() {
            guard let textView = textView else { return }
            var updatedParagraphs = [Paragraph]()

            for var paragraph in paragraphs {
                let rect = textView.layoutManager.boundingRect(forGlyphRange: paragraph.range, in: textView.textContainer)
                paragraph.height = rect.height
                paragraph.numberOfLines = Int((rect.height / textView.font!.lineHeight).rounded(.toNearestOrAwayFromZero))
                paragraph.screenPosition = CGPoint(x: rect.origin.x, y: rect.origin.y)

                updatedParagraphs.append(paragraph)
            }
            self.paragraphs = updatedParagraphs
        }

        func updateRuledViewFrame() {
            guard let textView = textView, let ruledView = ruledView else { return }
            let contentSize = textView.contentSize
            ruledView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
            ruledView.setNeedsDisplay()
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

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            updateParagraphSpatialProperties()
            self.contentOffset = scrollView.contentOffset
            ruledView?.setNeedsDisplay()

            // Check if content is scrollable and if scrolled to bottom
            let contentHeight = scrollView.contentSize.height
            let boundsHeight = scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
            let canScroll = contentHeight > boundsHeight
            let maxOffset = max(0, contentHeight - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            let isAtBottom = scrollView.contentOffset.y >= (maxOffset - 60.0)
            
            self.parent.canScroll = canScroll
            self.parent.isAtBottom = isAtBottom
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                let cursorLocation = textView.selectedRange.location
                
                self.parent.text = textView.attributedText
                let oldParagraphs = self.paragraphs
                self.parseAttributedText(textView.attributedText)
                let newParagraphs = self.paragraphs
                
                // Check if new paragraphs were added by comparing counts
                if newParagraphs.count > oldParagraphs.count && oldParagraphs.count > 0 {
                    self.animateNewParagraphSpacing(cursorLocation: cursorLocation)
                }
                self.lastParagraphCount = newParagraphs.count
                
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

        private func reconstructAttributedText() -> NSAttributedString {
            let mutableAttributedText = NSMutableAttributedString()
            for paragraph in paragraphs {
                let paragraphContent = NSMutableAttributedString(attributedString: paragraph.content)
                let contentRange = NSRange(location: 0, length: paragraphContent.length)

                // Apply the stored paragraph style over the entire range of the paragraph content.
                // This ensures that any updates (like from the pinch gesture) are reflected.
                if contentRange.length > 0 {
                    paragraphContent.addAttribute(.paragraphStyle, value: paragraph.paragraphStyle, range: contentRange)
                }

                mutableAttributedText.append(paragraphContent)
            }
            return mutableAttributedText
        }

        private func startSpacingAnimation(from: CGFloat, to: CGFloat, range: NSRange) {
            let startTime = CACurrentMediaTime()

            let displayLink = CADisplayLink(target: self, selector: #selector(self.updateSpacingAnimation(_:)))
            displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)

            let animation = ActiveAnimation(
                displayLink: displayLink,
                startTime: startTime,
                startSpacing: from,
                targetSpacing: to,
                range: range
            )

            activeAnimations[range] = animation
        }

@objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            guard let textView = textView else { return }

            if gesture.state == .began && gesture.numberOfTouches >= 2 {
                handlePinchBegan(gesture, textView: textView)
            } else if gesture.state == .changed {
                handlePinchChanged(gesture, textView: textView)
            } else if gesture.state == .ended || gesture.state == .cancelled {
                handlePinchEnded(gesture, textView: textView)
            }
        }

        private func handlePinchBegan(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            let location1 = gesture.location(ofTouch: 0, in: textView)
            let location2 = gesture.location(ofTouch: 1, in: textView)

            if let position1 = textView.closestPosition(to: location1), let position2 = textView.closestPosition(to: location2) {
                let range1 = paragraphRange(for: textView.attributedText, at: textView.offset(from: textView.beginningOfDocument, to: position1))
                let range2 = paragraphRange(for: textView.attributedText, at: textView.offset(from: textView.beginningOfDocument, to: position2))

                guard let index1 = paragraphs.firstIndex(where: { ($0.range == range1) || ($0.range.location == range1.location && $0.range.length == range1.length - 1) }),
                      let index2 = paragraphs.firstIndex(where: { ($0.range == range2) || ($0.range.location == range2.location && $0.range.length == range2.length - 1) }) else {
                    gesture.state = .cancelled
                    return
                }

                if index1 == index2 || abs(index1 - index2) != 1 {
                    gesture.state = .cancelled
                    return
                }

                let topRange = paragraphs[index1].range.location < paragraphs[index2].range.location
                    ? paragraphs[index1].range
                    : paragraphs[index2].range
                self.affectedParagraphRange = topRange
                self.pinchedParagraphIndices = [index1, index2]

                // Get current spacing - either from animation or from paragraph style
                let currentSpacing: CGFloat
                if let activeAnimation = activeAnimations[topRange] {
                    // Animation is in progress for this same range, calculate current position
                    let elapsed = CACurrentMediaTime() - activeAnimation.startTime
                    let duration = self.animationDuration
                    let progress = CGFloat(min(elapsed / duration, 1.0))
                    let easedProgress = EasingFunctions.easeOutBack(progress)
                    currentSpacing = activeAnimation.startSpacing + (activeAnimation.targetSpacing - activeAnimation.startSpacing) * easedProgress

                    // Stop current animation for this specific range
                    activeAnimation.displayLink.invalidate()
                    activeAnimations.removeValue(forKey: topRange)
                } else {
                    // No animation in progress for this range, use stored value
                    if let index = paragraphs.firstIndex(where: { $0.range == topRange }) {
                        currentSpacing = paragraphs[index].paragraphStyle.paragraphSpacing
                    } else {
                        currentSpacing = parent.settings.defaultParagraphSpacing
                    }
                }

                self.initialSpacing = currentSpacing
                self.currentDetent = currentSpacing

                // Set the initial detent for color and haptics
                self.lastClosestDetent = spacingDetents.min(by: { abs($0 - (self.initialSpacing ?? 0)) < abs($1 - (self.initialSpacing ?? 0)) })
                self.wasAtLimit = spacingDetents.contains { abs($0 - (self.initialSpacing ?? 0)) < 0.1 }

                // Track if we started at a limit for direction-based haptic
                self.startedAtLimit = self.wasAtLimit
                self.initialLimitValue = self.wasAtLimit ? self.lastClosestDetent : nil

                // Track this pinched pair like we track animations
                activePinchedPairs[topRange] = (indices: [index1, index2], timestamp: CACurrentMediaTime())

                // Update overlays with all active pinched pairs
                ruledView?.updateAllParagraphOverlays(
                    paragraphs: self.paragraphs,
                    textView: textView,
                    activePinchedPairs: activePinchedPairs,
                    currentGestureDetent: self.currentDetent,
                    currentGestureRange: topRange,
                )
            }
            gesture.scale = 1.0
            hapticGenerator.prepare()
        }

        private func handlePinchChanged(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            guard let initialSpacing = initialSpacing, let range = affectedParagraphRange else { return }

            // Symmetrical scaling logic
            let gestureRange = AppSettings.unrelatedParagraphSpacing - AppSettings.relatedParagraphSpacing
            let gestureProgress = (gesture.scale - 1.0) * gestureRange
            var targetSpacing = initialSpacing + gestureProgress

            // Clamp the spacing to the defined detents
            targetSpacing = max(AppSettings.relatedParagraphSpacing, min(targetSpacing, AppSettings.unrelatedParagraphSpacing))

            let closestDetentForColor = spacingDetents.min(by: { abs($0 - targetSpacing) < abs($1 - targetSpacing) }) ?? targetSpacing

            // Check if we're at full extension or contraction (matching a detent exactly)
            let isFullyExtendedOrContracted = spacingDetents.contains { detent in
                abs(detent - targetSpacing) < 0.1
            }

            if closestDetentForColor != lastClosestDetent {
                hapticGenerator.impactOccurred()
                hapticGenerator.prepare()
                lastClosestDetent = closestDetentForColor

                // Trigger heavy haptic border effect once using the primary paragraph
                if let range = affectedParagraphRange {
                    ruledView?.triggerHapticFeedback(for: range, type: .heavy)
                }
            } else if isFullyExtendedOrContracted {
                var shouldTriggerLight = false

                if !wasAtLimit {
                    // Not previously at limit - trigger once
                    shouldTriggerLight = true
                } else if startedAtLimit && initialLimitValue == targetSpacing {
                    // Started at this limit - check direction and if already triggered
                    let direction = gesture.scale - 1.0
                    let isMovingTowardLimit = (initialLimitValue == AppSettings.relatedParagraphSpacing && direction < 0) ||
                                            (initialLimitValue == AppSettings.unrelatedParagraphSpacing && direction > 0)

                    // Only trigger if moving toward limit and haven't triggered yet
                    shouldTriggerLight = isMovingTowardLimit && !hasTriggeredLightHaptic
                }

                if shouldTriggerLight {
                    lightHapticGenerator.impactOccurred()
                    lightHapticGenerator.prepare()
                    hasTriggeredLightHaptic = true

                    // Trigger light haptic border effect once using the primary paragraph
                    if let range = affectedParagraphRange {
                        ruledView?.triggerHapticFeedback(for: range, type: .light)
                    }
                }
            } else {
                // Reset trigger state when moving away from limit
                hasTriggeredLightHaptic = false
            }

            // Update limit state tracking
            wasAtLimit = isFullyExtendedOrContracted

            let currentStyle = paragraphs.first(where: { $0.range == range })?.paragraphStyle ?? NSParagraphStyle.default
            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.setParagraphStyle(currentStyle)
            newParagraphStyle.paragraphSpacing = targetSpacing

            textView.textStorage.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
            if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                paragraphs[index].paragraphStyle = newParagraphStyle
            }
            currentDetent = targetSpacing

            textView.layoutIfNeeded()
            ruledView?.updateAllParagraphOverlays(
                paragraphs: self.paragraphs,
                textView: textView,
                activePinchedPairs: activePinchedPairs,
                currentGestureDetent: self.currentDetent,
                currentGestureRange: range,
            )
            ruledView?.setNeedsDisplay()
        }

        private func handlePinchEnded(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            guard let currentSpacing = self.currentDetent, let range = affectedParagraphRange else { return }

            let closestDetent = spacingDetents.min(by: { abs($0 - currentSpacing) < abs($1 - currentSpacing) }) ?? self.parent.settings.defaultParagraphSpacing

            // Reset tracking variables
            self.startedAtLimit = false
            self.initialLimitValue = nil
            self.hasTriggeredLightHaptic = false

            // Start smooth animation from current spacing to target
            startSpacingAnimation(from: currentSpacing, to: closestDetent ?? self.parent.settings.defaultParagraphSpacing, range: range)
        }

        @objc private func updateSpacingAnimation(_ displayLink: CADisplayLink) {
            guard let textView = textView else { return }

            for (range, animation) in activeAnimations {
                let elapsed = CACurrentMediaTime() - animation.startTime
                let duration = self.animationDuration

                if elapsed >= duration {
                    // Animation complete
                    animation.displayLink.invalidate()
                    activeAnimations.removeValue(forKey: range)

                    // Final update
                    let finalParagraphStyle = NSMutableParagraphStyle()
                    finalParagraphStyle.setParagraphStyle(textView.attributedText.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default)
                    finalParagraphStyle.paragraphSpacing = animation.targetSpacing

                    textView.textStorage.addAttribute(.paragraphStyle, value: finalParagraphStyle, range: range)
                    if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                        paragraphs[index].paragraphStyle = finalParagraphStyle
                    }

                    // Clean up active pinched pairs
                    activePinchedPairs.removeValue(forKey: range)

                    textView.layoutIfNeeded()
                    ruledView?.updateAllParagraphOverlays(
                        paragraphs: self.paragraphs,
                        textView: textView,
                        activePinchedPairs: activePinchedPairs,
                        currentGestureDetent: nil,
                        currentGestureRange: nil
                    )

                    // Completion haptic
                    completionHapticGenerator.impactOccurred()
                    if activeAnimations.isEmpty {
                        self.parent.text = self.reconstructAttributedText()
                        self.initialSpacing = nil
                        self.affectedParagraphRange = nil
                        self.currentDetent = nil
                        self.lastClosestDetent = nil
                    }
                } else {
                    let progress = CGFloat(elapsed / duration)
                    let easedProgress = EasingFunctions.easeOutBack(progress)
                    let currentSpacing = animation.startSpacing + (animation.targetSpacing - animation.startSpacing) * easedProgress

                    let currentParagraphStyle = NSMutableParagraphStyle()
                    currentParagraphStyle.setParagraphStyle(textView.attributedText.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default)
                    currentParagraphStyle.paragraphSpacing = currentSpacing

                    textView.textStorage.addAttribute(.paragraphStyle, value: currentParagraphStyle, range: range)
                    if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                        paragraphs[index].paragraphStyle = currentParagraphStyle
                    }

                    textView.layoutIfNeeded()
                    ruledView?.updateAllParagraphOverlays(
                        paragraphs: self.paragraphs,
                        textView: textView,
                        activePinchedPairs: activePinchedPairs,
                        currentGestureDetent: nil,
                        currentGestureRange: nil
                    )
                }
            }
        }

        func scrollToBottom() {
            guard let textView = self.textView else { return }
            let contentHeight = textView.contentSize.height
            let maxOffset = max(0, contentHeight - textView.bounds.height + textView.adjustedContentInset.bottom)
            let bottomOffset = CGPoint(x: 0, y: maxOffset)

            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                textView.setContentOffset(bottomOffset, animated: false)
            }, completion: nil)
        }
        
        private func animateNewParagraphSpacing(cursorLocation: Int) {
            guard let textView = textView, paragraphs.count >= 2 else { return }
            
            // Find which paragraph contains the cursor (the new paragraph)
            let cursorParagraphIndex = paragraphs.firstIndex { paragraph in
                paragraph.range.contains(cursorLocation)
            }
            
            guard let cursorIndex = cursorParagraphIndex, cursorIndex > 0 else { return }
            
            // The paragraph to animate is the one before the new paragraph
            let animateIndex = cursorIndex - 1
            let animateParagraph = paragraphs[animateIndex]
            let currentSpacing = animateParagraph.paragraphStyle.paragraphSpacing
            
            // Only animate if the existing paragraph had unrelated spacing
            // Use a more lenient comparison for floating point values
            guard abs(currentSpacing - AppSettings.unrelatedParagraphSpacing) < 1.0 else { return }
            
            let animateRange = animateParagraph.range
            
            // Start with related spacing and animate to unrelated spacing
            let startSpacing = AppSettings.relatedParagraphSpacing
            let targetSpacing = AppSettings.unrelatedParagraphSpacing
            
            // Create animation state
            let displayLink = CADisplayLink(target: self, selector: #selector(updateSpacingAnimation(_:)))
            displayLink.add(to: .main, forMode: .common)
            let animation = ActiveAnimation(displayLink: displayLink, startTime: CACurrentMediaTime(), startSpacing: startSpacing, targetSpacing: targetSpacing, range: animateRange)
            activeAnimations[animateRange] = animation
            
            // Set initial spacing immediately
            let initialParagraphStyle = NSMutableParagraphStyle()
            initialParagraphStyle.setParagraphStyle(animateParagraph.paragraphStyle)
            initialParagraphStyle.paragraphSpacing = startSpacing
            
            textView.textStorage.addAttribute(.paragraphStyle, value: initialParagraphStyle, range: animateRange)
            if let index = paragraphs.firstIndex(where: { $0.range == animateRange }) {
                paragraphs[index].paragraphStyle = initialParagraphStyle
            }
        }
    }
}
