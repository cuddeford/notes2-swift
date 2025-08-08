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
    @Binding var isAtTop: Bool

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

        // Apply default style based on user preference if the text view is empty
        if textView.attributedText.length == 0 {
            let useBigFont = UserDefaults.standard.bool(forKey: "newNoteWithBigFont")
            let style: NoteTextStyle = useBigFont ? .title1 : .body
            let traits: UIFontDescriptor.SymbolicTraits = useBigFont ? .traitBold : []
            let defaultFont = UIFont.noteStyle(style, traits: traits)
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

        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPressGesture(_:)))
        longPressGesture.minimumPressDuration = 0.25
        longPressGesture.allowableMovement = 20
        textView.addGestureRecognizer(longPressGesture)

        let swipeToReplyGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeToReplyGesture(_:)))
        swipeToReplyGesture.delegate = context.coordinator
        textView.addGestureRecognizer(swipeToReplyGesture)

        context.coordinator.textView = textView
        context.coordinator.textContainerInset = textView.textContainerInset
        context.coordinator.textViewWidth = textView.bounds.width

        context.coordinator.parseAttributedText(textView.attributedText)

        DispatchQueue.main.async { // Ensure UI updates happen on the main thread
            textView.becomeFirstResponder()
            context.coordinator.parseAttributedText(textView.attributedText)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.parseAttributedText(textView.attributedText)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            context.coordinator.parseAttributedText(textView.attributedText)
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

        // Activation thresholds for gesture priming
        private let activationThreshold: CGFloat = 30
        private let spacingTolerance: CGFloat = 0.1
        private var relatedActivationThreshold: CGFloat { AppSettings.relatedParagraphSpacing + activationThreshold }
        private var unrelatedActivationThreshold: CGFloat { AppSettings.unrelatedParagraphSpacing - activationThreshold }
        
        private enum ThresholdType {
            case relatedAbove
            case unrelatedBelow
            case middleRelated
            case middleUnrelated
        }
        
        private var lastCrossedThreshold: ThresholdType? = nil
        var gesturePrimed: Bool = false
        private var activeAnimations: [NSRange: ActiveAnimation] = [:]
        private var lastParagraphCount: Int = 0
        private var initialPinchDistance: CGFloat?
        var activePinchedPairs: [NSRange: (indices: [Int], timestamp: CFTimeInterval)] = [:]
        private var pinchedParagraphIndices: [Int] = []
        var isPinching: Bool = false

        // Drag-to-reorder state
        private var draggingParagraphIndex: Int?
        private var dragGhostView: UIView?
        private var dragInitialLocation: CGPoint?
        private var dragTargetIndex: Int?
        private var draggedParagraphID: UUID?
        var isDragging: Bool = false
        private let showGhostOverlay = false
        private let dragHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private let dragSelectionGenerator = UISelectionFeedbackGenerator()

        // Auto-scrolling state for drag-to-reorder
        private var scrollDisplayLink: CADisplayLink?
        private var isAutoScrolling: Bool = false
        private let scrollEdgeThreshold: CGFloat = 80.0
        private let maxScrollSpeed: CGFloat = 1200.0
        private let minScrollSpeed: CGFloat = 200.0

        // Multitouch support for drag + manual scroll
        private var initialTouchCount: Int = 1
        private var isMultitouchDrag: Bool = false

        // Reply gesture state
        private var replyGestureParagraphIndex: Int?
        private var replyGhostView: UIView?
        private var replyOverlayView: UIView?
        private var replyGestureInitialLocation: CGPoint?
        private let replyGestureThreshold: CGFloat = 75.0
        private let replyGestureHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private var hasTriggeredReplyHaptic = false
        private var isHorizontalSwipe = false
        private var swipeDirection: SwipeDirection = .none

        // Hold-to-confirm state
        private var holdStartTime: CFTimeInterval?
        private var isHolding = false
        private var holdProgress: CGFloat = 0.0
        private let holdDuration: CFTimeInterval = 0.8
        private let holdHapticGenerator = UIImpactFeedbackGenerator(style: .light)
        private var holdProgressView: UIView?
        private var holdDisplayLink: CADisplayLink?

        enum SwipeDirection {
            case none
            case right
            case left
        }

        @Published var paragraphs: [Paragraph] = []
        @Published var textContainerInset: UIEdgeInsets = .zero
        @Published var contentOffset: CGPoint = .zero
        @Published var textViewWidth: CGFloat = 0
        @Published var currentDetent: CGFloat?

        init(_ parent: RichTextEditor) {
            self.parent = parent
            super.init()
        }

        func hideKeyboard() {
            guard let textView = textView else { return }
            textView.endEditing(true)
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

            // Preserve existing UUIDs for paragraphs that haven't changed
            let oldParagraphs = self.paragraphs
            var finalParagraphs: [Paragraph] = []
            var consumedOldIndices = Set<Int>() // Track indices of old paragraphs that have been matched

            for var newP in newParagraphs { // Use 'var' to allow modification
                for (oldIndex, oldP) in oldParagraphs.enumerated() {
                    if !consumedOldIndices.contains(oldIndex) && oldP.content.isEqual(to: newP.content) && oldP.paragraphStyle == newP.paragraphStyle {
                        // If content and paragraph style match, reuse the old paragraph's UUID
                        newP.id = oldP.id
                        consumedOldIndices.insert(oldIndex) // Mark as consumed

                        break // Found a match for this new paragraph, move to next newP
                    }
                }
                finalParagraphs.append(newP)
            }
            self.paragraphs = finalParagraphs
            self.lastParagraphCount = finalParagraphs.count
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
            for i in 0..<paragraphs.count {
                let paragraph = paragraphs[i]
                let rect = textView.layoutManager.boundingRect(forGlyphRange: paragraph.range, in: textView.textContainer)
                paragraphs[i].height = rect.height
                paragraphs[i].numberOfLines = Int((rect.height / textView.font!.lineHeight).rounded(.toNearestOrAwayFromZero))
                paragraphs[i].screenPosition = CGPoint(x: rect.origin.x, y: rect.origin.y)
            }
        }

        func updateRuledViewFrame() {
            guard let textView = textView, let ruledView = ruledView else { return }
            let contentSize = textView.contentSize
            ruledView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
            ruledView.setNeedsDisplay()
        }

        func updateTypingAttributes() {
            guard let textView = textView else { return }
            let loc = max(0, min(textView.selectedRange.location, textView.attributedText.length - 1))
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
            let isAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 60.0

            if !self.isPinching && self.parent.isAtBottom != isAtBottom || self.parent.canScroll != canScroll || self.parent.isAtTop != isAtTop {
                self.parent.canScroll = canScroll
                self.parent.isAtBottom = isAtBottom
                self.parent.isAtTop = isAtTop
            }

            // Check for magnetic zone transitions during scrolling, but only when user is dragging
            if !self.isPinching && parent.settings.magneticScrollingEnabled {
                checkMagneticZoneTransition()
            }
        }

        // MARK: - Instagram Reels-Style Magnetic Paragraph Scrolling

        private var currentMagneticParagraph: Paragraph? = nil
        private let selectionHapticGenerator = UISelectionFeedbackGenerator()
        private var isUserDragging: Bool = false

        private func findParagraphToSnap() -> Paragraph? {
            guard let textView = textView, paragraphs.count > 1 else { return nil }

            let screenTopY = textView.contentOffset.y + textView.textContainerInset.top
            let activationWindow: CGFloat = 20.0 // ±10pt from screen top

            // Find the paragraph whose top edge is closest to screen top, excluding first and last paragraphs
            var closestParagraph: Paragraph?
            var minDistance: CGFloat = .infinity

            for (index, paragraph) in paragraphs.enumerated() {
                // Skip the first and last paragraphs
                guard index > 0 && index < paragraphs.count - 1 else { continue }

                let paragraphTop = paragraph.screenPosition.y
                let distance = abs(paragraphTop - screenTopY)

                // Only consider paragraphs within the activation window
                if distance <= activationWindow && distance < minDistance {
                    closestParagraph = paragraph
                    minDistance = distance
                }
            }

            return closestParagraph
        }

        private func findCenteredParagraph() -> Paragraph? {
            guard let textView = textView, paragraphs.count > 1 else { return nil }

            let screenTopY = textView.contentOffset.y + textView.textContainerInset.top
            let centerThreshold: CGFloat = 10.0 // ±5pt tolerance for center detection

            // Find the paragraph whose top edge is exactly at screen top, excluding first and last paragraphs
            for (index, paragraph) in paragraphs.enumerated() {
                // Skip the first and last paragraphs
                guard index > 0 && index < paragraphs.count - 1 else { continue }

                let paragraphTop = paragraph.screenPosition.y
                let distance = abs(paragraphTop - screenTopY)

                // Only return paragraph if it's perfectly centered
                if distance <= centerThreshold {
                    return paragraph
                }
            }

            return nil
        }

        private func checkMagneticZoneTransition() {
            let centeredParagraph = findCenteredParagraph()

            // Only trigger haptic when paragraph is perfectly centered
            if let centered = centeredParagraph, centered.id != currentMagneticParagraph?.id {
                selectionHapticGenerator.selectionChanged()
                currentMagneticParagraph = centered
            } else if centeredParagraph == nil {
                // Clear current paragraph when no longer centered
                currentMagneticParagraph = nil
            }
        }

        private func applyMagneticSnap(to paragraph: Paragraph) {
            guard let textView = textView else { return }

            let targetOffsetY = paragraph.screenPosition.y - textView.textContainerInset.top - 45
            let maxOffsetY = max(0, textView.contentSize.height - textView.bounds.height + textView.adjustedContentInset.bottom)
            let finalOffsetY = max(0, min(targetOffsetY, maxOffsetY))

            let lightHapticGenerator = UIImpactFeedbackGenerator(style: .light)
            lightHapticGenerator.impactOccurred()

            // Instagram Reels-style smooth snap animation
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    textView.setContentOffset(CGPoint(x: 0, y: finalOffsetY), animated: false)
                },
                completion: nil
            )
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserDragging = true
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Trigger magnetic snap after deceleration
            if parent.settings.magneticScrollingEnabled, let paragraphToSnap = findParagraphToSnap() {
                applyMagneticSnap(to: paragraphToSnap)
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            isUserDragging = false
            // Always snap immediately when gesture ends, regardless of deceleration
            if parent.settings.magneticScrollingEnabled {
                if let paragraphToSnap = findParagraphToSnap() {
                    applyMagneticSnap(to: paragraphToSnap)
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            DispatchQueue.main.async {
                let cursorLocation = textView.selectedRange.location

                self.parent.text = textView.attributedText
                if !self.isDragging {
                    let oldParagraphs = self.paragraphs
                    self.parseAttributedText(textView.attributedText)
                    let newParagraphs = self.paragraphs

                    // Check if new paragraphs were added by comparing counts
                    if newParagraphs.count > oldParagraphs.count && oldParagraphs.count > 0 {
                        self.animateNewParagraphSpacing(cursorLocation: cursorLocation)
                    }
                    self.lastParagraphCount = newParagraphs.count
                }

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

        private func startSpacingAnimation(from: CGFloat, to: CGFloat, range: NSRange, actionState: Bool) {
            let startTime = CACurrentMediaTime()

            let displayLink = CADisplayLink(target: self, selector: #selector(self.updateSpacingAnimation(_:)))
            displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)

            let animation = ActiveAnimation(
                displayLink: displayLink,
                startTime: startTime,
                startSpacing: from,
                targetSpacing: to,
                range: range,
                actionState: actionState
            )

            activeAnimations[range] = animation
        }

        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            guard let textView = textView, !isDragging else { return }

            if gesture.state == .began && gesture.numberOfTouches >= 2 {
                handlePinchBegan(gesture, textView: textView)
            } else if gesture.state == .changed {
                handlePinchChanged(gesture, textView: textView)
            } else if gesture.state == .ended || gesture.state == .cancelled {
                handlePinchEnded(gesture, textView: textView)
            }
        }

        private func handlePinchBegan(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            self.isPinching = true

            guard gesture.numberOfTouches >= 2 else {
                gesture.state = .cancelled
                return
            }

            let location1 = gesture.location(ofTouch: 0, in: textView)
            let location2 = gesture.location(ofTouch: 1, in: textView)

            let dx = location2.x - location1.x
            let dy = location2.y - location1.y
            self.initialPinchDistance = sqrt(dx*dx + dy*dy)

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
                self.wasAtLimit = spacingDetents.contains { abs($0 - (self.initialSpacing ?? 0)) < spacingTolerance }

                // Track if we started at a limit for direction-based haptic
                self.startedAtLimit = self.wasAtLimit
                self.initialLimitValue = self.wasAtLimit ? self.lastClosestDetent : nil

                // Reset threshold tracking for bidirectional crossing
                self.lastCrossedThreshold = nil
                self.gesturePrimed = false

                // Track this pinched pair like we track animations
                activePinchedPairs[topRange] = (indices: [index1, index2], timestamp: CACurrentMediaTime())

                // Update overlays with all active pinched pairs
                ruledView?.updateAllParagraphOverlays(
                    paragraphs: self.paragraphs,
                    textView: textView,
                    activePinchedPairs: activePinchedPairs,
                    currentGestureDetent: self.currentDetent,
                    currentGestureRange: topRange
                )
            }
            gesture.scale = 1.0
            hapticGenerator.prepare()
        }

        private func handlePinchChanged(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            guard let initialSpacing = initialSpacing, let range = affectedParagraphRange, let initialPinchDistance = initialPinchDistance else { return }

            guard gesture.numberOfTouches >= 2 else { return }

            let location1 = gesture.location(ofTouch: 0, in: textView)
            let location2 = gesture.location(ofTouch: 1, in: textView)

            let dx = location2.x - location1.x
            let dy = location2.y - location1.y
            let currentDistance = sqrt(dx*dx + dy*dy)

            let delta = currentDistance - initialPinchDistance
            var targetSpacing = initialSpacing + delta

            // Clamp the spacing to the defined detents
            targetSpacing = max(AppSettings.relatedParagraphSpacing, min(targetSpacing, AppSettings.unrelatedParagraphSpacing))

            let direction = currentDistance - initialPinchDistance
            let crossingResult = checkThresholdCrossing(
                currentSpacing: targetSpacing,
                initialSpacing: initialSpacing,
                relatedThreshold: relatedActivationThreshold,
                unrelatedThreshold: unrelatedActivationThreshold
            )

            if crossingResult.crossed {
                hapticGenerator.impactOccurred()
                hapticGenerator.prepare()
                
                gesturePrimed = crossingResult.newState
                lastCrossedThreshold = crossingResult.thresholdType
                
                if let range = affectedParagraphRange {
                    ruledView?.triggerHapticFeedback(for: range, type: .heavy)
                }
            } else if lastCrossedThreshold == nil {
                gesturePrimed = false
            }

            // Restore light haptic for physical limits
            let isAtLimit = spacingDetents.contains { detent in
                abs(detent - targetSpacing) < spacingTolerance
            }

            if isAtLimit {
                var shouldTriggerLight = false

                if !wasAtLimit {
                    // Not previously at limit - trigger once
                    shouldTriggerLight = true
                } else if startedAtLimit && initialLimitValue == targetSpacing {
                    // Started at this limit - check direction and if already triggered
                    let isMovingTowardLimit = (initialLimitValue == AppSettings.relatedParagraphSpacing && direction < 0) ||
                                            (initialLimitValue == AppSettings.unrelatedParagraphSpacing && direction > 0)

                    // Only trigger if moving toward limit and haven't triggered yet
                    shouldTriggerLight = isMovingTowardLimit && !hasTriggeredLightHaptic
                }

                if shouldTriggerLight {
                    lightHapticGenerator.impactOccurred()
                    lightHapticGenerator.prepare()
                    hasTriggeredLightHaptic = true

                    // Trigger light haptic border effect
                    if let range = affectedParagraphRange {
                        ruledView?.triggerHapticFeedback(for: range, type: .light)
                    }
                }
            }

            // Update limit state tracking
            wasAtLimit = isAtLimit

            let currentStyle = paragraphs.first(where: { $0.range == range })?.paragraphStyle ?? NSParagraphStyle.default
            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.setParagraphStyle(currentStyle)
            newParagraphStyle.paragraphSpacing = targetSpacing

            textView.textStorage.addAttribute(.paragraphStyle, value: newParagraphStyle, range: range)
            if let index = paragraphs.firstIndex(where: { $0.range == range }) {
                paragraphs[index].paragraphStyle = newParagraphStyle
            }

            textView.layoutIfNeeded()
            ruledView?.updateAllParagraphOverlays(
                paragraphs: self.paragraphs,
                textView: textView,
                activePinchedPairs: activePinchedPairs,
                currentGestureDetent: self.currentDetent,
                currentGestureRange: range,
                actionState: false
            )
            ruledView?.setNeedsDisplay()

            currentDetent = targetSpacing
        }
        
        private func checkThresholdCrossing(
            currentSpacing: CGFloat,
            initialSpacing: CGFloat,
            relatedThreshold: CGFloat,
            unrelatedThreshold: CGFloat
        ) -> (crossed: Bool, newState: Bool, thresholdType: ThresholdType?) {
            let wasInitiallyRelated = abs(initialSpacing - AppSettings.relatedParagraphSpacing) < spacingTolerance
            let wasInitiallyUnrelated = abs(initialSpacing - AppSettings.unrelatedParagraphSpacing) < spacingTolerance
            
            var crossingOccurred = false
            var newPrimedState = false
            var thresholdType: ThresholdType? = nil
            
            if wasInitiallyRelated {
                let wasAbove = lastCrossedThreshold == .relatedAbove
                let isAbove = currentSpacing >= relatedThreshold
                
                if wasAbove != isAbove {
                    crossingOccurred = true
                    newPrimedState = isAbove
                    thresholdType = isAbove ? .relatedAbove : nil
                }
            } else if wasInitiallyUnrelated {
                let wasBelow = lastCrossedThreshold == .unrelatedBelow
                let isBelow = currentSpacing <= unrelatedThreshold
                
                if wasBelow != isBelow {
                    crossingOccurred = true
                    newPrimedState = isBelow
                    thresholdType = isBelow ? .unrelatedBelow : nil
                }
            } else {
                let relatedCrossed = currentSpacing >= relatedThreshold
                let unrelatedCrossed = currentSpacing <= unrelatedThreshold
                
                let relatedDist = abs(currentSpacing - relatedThreshold)
                let unrelatedDist = abs(currentSpacing - unrelatedThreshold)
                
                if relatedDist < unrelatedDist {
                    let wasAbove = lastCrossedThreshold == .middleRelated
                    if relatedCrossed != wasAbove {
                        crossingOccurred = true
                        newPrimedState = relatedCrossed
                        thresholdType = relatedCrossed ? .middleRelated : nil
                    }
                } else {
                    let wasBelow = lastCrossedThreshold == .middleUnrelated
                    if unrelatedCrossed != wasBelow {
                        crossingOccurred = true
                        newPrimedState = unrelatedCrossed
                        thresholdType = unrelatedCrossed ? .middleUnrelated : nil
                    }
                }
            }
            
            return (crossed: crossingOccurred, newState: newPrimedState, thresholdType: thresholdType)
        }

        private func handlePinchEnded(_ gesture: UIPinchGestureRecognizer, textView: UITextView) {
            guard let currentSpacing = self.currentDetent, let range = affectedParagraphRange else { return }

            // Determine target spacing based on activation thresholds
            let targetSpacing: CGFloat
            let wasInitiallyRelated = abs(initialSpacing ?? 0 - AppSettings.relatedParagraphSpacing) < spacingTolerance
            let wasInitiallyUnrelated = abs(initialSpacing ?? 0 - AppSettings.unrelatedParagraphSpacing) < spacingTolerance

            if wasInitiallyRelated {
                // Started at related, use activation threshold
                targetSpacing = currentSpacing >= relatedActivationThreshold ? AppSettings.unrelatedParagraphSpacing : AppSettings.relatedParagraphSpacing
            } else if wasInitiallyUnrelated {
                // Started at unrelated, use activation threshold
                targetSpacing = currentSpacing <= unrelatedActivationThreshold ? AppSettings.relatedParagraphSpacing : AppSettings.unrelatedParagraphSpacing
            } else {
                // Started in middle, use activation thresholds
                // Determine which activation threshold is closer
                let relatedDist = abs(currentSpacing - relatedActivationThreshold)
                let unrelatedDist = abs(currentSpacing - unrelatedActivationThreshold)

                // Use the closer threshold to determine snap direction
                if relatedDist < unrelatedDist {
                    // Related threshold (82) is closer, use it for snapping
                    targetSpacing = currentSpacing >= relatedActivationThreshold ? AppSettings.unrelatedParagraphSpacing : AppSettings.relatedParagraphSpacing
                } else {
                    // Unrelated threshold (200) is closer, use it for snapping
                    targetSpacing = currentSpacing <= unrelatedActivationThreshold ? AppSettings.relatedParagraphSpacing : AppSettings.unrelatedParagraphSpacing
                }
            }

            // Store the current action state for animation (preserve gesturePrimed across animation)
            let finalActionState = gesturePrimed

            // Reset tracking variables but preserve gesturePrimed for animation
            self.startedAtLimit = false
            self.initialLimitValue = nil
            self.hasTriggeredLightHaptic = false
            self.lastCrossedThreshold = nil
            // Keep gesturePrimed true during animation, reset after animation completes

            // Start smooth animation from current spacing to target, preserving action state
            startSpacingAnimation(from: currentSpacing, to: targetSpacing, range: range, actionState: finalActionState)
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
                        currentGestureRange: nil,
                        actionState: false
                    )

                    // Completion haptic
                    completionHapticGenerator.impactOccurred()
                    if activeAnimations.isEmpty {
                        self.parent.text = self.reconstructAttributedText()
                        self.initialSpacing = nil
                        self.affectedParagraphRange = nil
                        self.currentDetent = nil
                        self.lastClosestDetent = nil
                        self.isPinching = false
                        self.gesturePrimed = false  // Reset gesturePrimed after animation completes
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
                        currentGestureRange: nil,
                        actionState: animation.actionState
                    )
                }
            }
        }

        func scrollToBottom() {
            guard let textView = self.textView else { return }
            let contentHeight = textView.contentSize.height
            let maxOffset = max(0, contentHeight - textView.bounds.height + textView.adjustedContentInset.bottom)
            let bottomOffset = CGPoint(x: 0, y: maxOffset)

            textView.setContentOffset(bottomOffset, animated: true)
        }

        func scrollToTop() {
            guard let textView = self.textView else { return }
            let topOffset = CGPoint(x: 0, y: -textView.adjustedContentInset.top)
            textView.setContentOffset(topOffset, animated: true)
        }

        private func animateNewParagraphSpacing(cursorLocation: Int) {
            guard let textView = textView, paragraphs.count >= 2 else { return }

            // Find which paragraph contains the cursor (the new paragraph)
            let cursorParagraphIndex = paragraphs.firstIndex { paragraph in
                paragraph.range.contains(cursorLocation)
            }

            // Determine which paragraph to animate
            let animateIndex: Int

            if let cursorIndex = cursorParagraphIndex {
                // Cursor is inside an existing paragraph (middle insertion)
                guard cursorIndex > 0 else { return }
                animateIndex = cursorIndex - 1
            } else if cursorLocation >= textView.text.count {
                // Cursor is at the very end, new paragraph after last
                guard paragraphs.count >= 2 else { return }
                animateIndex = paragraphs.count - 2
            } else {
                return
            }

            // Ensure animateIndex is valid
            guard animateIndex < paragraphs.count else { return }
            let animateParagraph = paragraphs[animateIndex]
            let currentSpacing = animateParagraph.paragraphStyle.paragraphSpacing

            let animateRange = animateParagraph.range

            // Animate to unrelated spacing
            let startSpacing = 0.0
            let targetSpacing = currentSpacing

            // Create animation state
            let displayLink = CADisplayLink(target: self, selector: #selector(updateSpacingAnimation(_:)))
            displayLink.add(to: .main, forMode: .common)
            let animation = ActiveAnimation(displayLink: displayLink, startTime: CACurrentMediaTime(), startSpacing: startSpacing, targetSpacing: targetSpacing, range: animateRange, actionState: false)
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

        // MARK: - Drag-to-Reorder Gesture Handling

        @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
            guard let textView = textView else { return }
            guard AppSettings.shared.dragToReorderParagraphEnabled else { return }

            let location = gesture.location(in: textView)

            switch gesture.state {
            case .began:
                handleDragBegan(location: location, textView: textView, gesture: gesture)
            case .changed:
                handleDragChanged(location: location, textView: textView, gesture: gesture)
            case .ended, .cancelled:
                handleDragEnded(location: location, textView: textView, gesture: gesture)
            default:
                break
            }
        }

        private func handleDragBegan(location: CGPoint, textView: UITextView, gesture: UILongPressGestureRecognizer) {
            // Find which paragraph contains the press location
            guard let index = paragraphIndex(at: location, textView: textView) else { return }

            // Prepare haptics
            dragSelectionGenerator.prepare()
            dragHapticGenerator.prepare()

            dragSelectionGenerator.selectionChanged()

            draggingParagraphIndex = index
            draggedParagraphID = paragraphs[index].id
            dragInitialLocation = location

            // Track initial touch count for multitouch detection
            initialTouchCount = gesture.numberOfTouches
            isMultitouchDrag = false

            // Create ghost view if enabled
            if showGhostOverlay {
                createDragGhost(for: paragraphs[index], at: index, textView: textView)
            }

            // Highlight the source paragraph
            setDraggingSource(index)
            isDragging = true
        }

        private func handleDragChanged(location: CGPoint, textView: UITextView, gesture: UILongPressGestureRecognizer) {
            guard draggedParagraphID != nil else { return }

            // Check for multitouch transition
            let currentTouchCount = gesture.numberOfTouches
            if currentTouchCount > initialTouchCount {
                isMultitouchDrag = true
                stopAutoScroll() // Stop auto-scroll when second finger is added
            }

            // Update drag location for auto-scrolling
            dragInitialLocation = location

            // Check for auto-scrolling (only if not multitouch scrolling)
            if !isMultitouchDrag {
                checkAutoScroll(location: location, textView: textView)
            }

            // Find target insertion index
            let newTargetIndex = calculateTargetIndex(for: location, textView: textView)

            // Move paragraph immediately when target changes
            let currentDragIndex = draggingParagraphIndex ?? 0
            if newTargetIndex != currentDragIndex {
                reorderParagraph(from: currentDragIndex, to: newTargetIndex, textView: textView, isLiveDrag: true)

                // Update drag index to reflect new position
                draggingParagraphIndex = newTargetIndex
                dragTargetIndex = newTargetIndex

                // Update the blue styling to the new position
                setDraggingSource(newTargetIndex)

                // Haptic feedback for movement - only when index actually changes
                dragSelectionGenerator.selectionChanged()
            }

            // Update ghost position based on current paragraph position if ghost is enabled
            if showGhostOverlay, let ghostView = dragGhostView, let currentIndex = draggingParagraphIndex {
                let currentParagraph = paragraphs[currentIndex]
                let paragraphFrame = textView.layoutManager.boundingRect(
                    forGlyphRange: currentParagraph.range,
                    in: textView.textContainer
                ).offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)

                // Calculate offset from initial touch to maintain drag continuity
                let touchOffset = CGPoint(
                    x: location.x - (dragInitialLocation?.x ?? 0),
                    y: location.y - (dragInitialLocation?.y ?? 0)
                )

                // Position ghost relative to current paragraph position
                ghostView.center = CGPoint(
                    x: ghostView.center.x,
                    y: paragraphFrame.midY + touchOffset.y
                )
            }
        }

        private func handleDragEnded(location: CGPoint, textView: UITextView, gesture: UILongPressGestureRecognizer) {
            // Paragraph has already been moved during drag, just clean up
            cleanupDrag()
            isDragging = false
            isMultitouchDrag = false

            // Re-parse attributed text to ensure paragraph ranges are up-to-date
            self.parseAttributedText(textView.attributedText)

            // Final haptic feedback for drop completion
            dragHapticGenerator.impactOccurred()

            // Ensure cursor is visible after final drop
            centerCursorInTextView()
        }

        private func paragraphIndex(at location: CGPoint, textView: UITextView) -> Int? {
            let adjustedLocation = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )

            // Use the overlay frames from RuledView for consistent positioning
            if let ruledView = ruledView {
                for index in 0..<paragraphs.count {
                    if let overlayFrame = ruledView.getOverlayFrame(forParagraphAtIndex: index) {
                        // The overlay frame already includes textContainerInset, so we need to adjust it back
                        let adjustedFrame = overlayFrame.offsetBy(dx: -textView.textContainerInset.left, dy: -textView.textContainerInset.top)
                        if adjustedFrame.contains(adjustedLocation) {
                            return index
                        }
                    }
                }
            }

            // Fallback to layout-based detection if overlays aren't available
            for (index, paragraph) in paragraphs.enumerated() {
                var rect = textView.layoutManager.boundingRect(
                    forGlyphRange: paragraph.range,
                    in: textView.textContainer
                )

                if index == paragraphs.count - 1 {
                    // Last paragraph - use full width for consistent touch area
                    rect = CGRect(
                        x: 0,
                        y: rect.minY,
                        width: textView.textContainer.size.width,
                        height: max(rect.height, textView.font?.lineHeight ?? 20)
                    )
                }

                if rect.contains(adjustedLocation) {
                    return index
                }
            }
            return nil
        }

        private func createDragGhost(for paragraph: Paragraph, at index: Int, textView: UITextView) {
            // Use the RuledView to get the exact frame of the overlay
            guard let snapshotRect = ruledView?.getOverlayFrame(forParagraphAtIndex: index) else {
                return
            }

            // Create a snapshot of the paragraph area, including the RuledView overlay
            guard let snapshotView = textView.resizableSnapshotView(from: snapshotRect, afterScreenUpdates: true, withCapInsets: .zero) else {
                return // Or handle error appropriately
            }

            // Create a container to hold the snapshot and apply the shadow to it
            let ghostContainerView = UIView(frame: snapshotRect)

            // Configure the shadow on the container
            ghostContainerView.layer.shadowColor = UIColor.label.cgColor
            ghostContainerView.layer.shadowOpacity = 0.3
            ghostContainerView.layer.shadowOffset = CGSize(width: 0, height: 5)
            ghostContainerView.layer.shadowRadius = 10.0
            ghostContainerView.layer.shadowPath = UIBezierPath(roundedRect: ghostContainerView.bounds, cornerRadius: ruledView?.overlayCornerRadius ?? 20.0).cgPath

            // This view will have the opaque background and clip its subviews.
            let clippingView = UIView(frame: ghostContainerView.bounds)
            clippingView.layer.cornerRadius = ruledView?.overlayCornerRadius ?? 20.0
            clippingView.layer.masksToBounds = true
            clippingView.backgroundColor = .systemBackground.withAlphaComponent(0.8) // Semi-opaque background
            ghostContainerView.addSubview(clippingView)

            // The snapshot view is placed inside the clipping view.
            // Its semi-transparent content will blend with the clippingView's opaque background.
            snapshotView.frame = clippingView.bounds
            clippingView.addSubview(snapshotView)

            ghostContainerView.alpha = 0

            textView.addSubview(ghostContainerView)
            dragGhostView = ghostContainerView

            // Animate appearance
            UIView.animate(withDuration: 0.2) {
                ghostContainerView.alpha = 1.0
            }
        }

        private func calculateTargetIndex(for location: CGPoint, textView: UITextView) -> Int {
            guard let dragIndex = draggingParagraphIndex else { return 0 }

            let adjustedLocation = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )

            // Calculate target based on vertical position between paragraphs
            var paragraphRects: [CGRect] = []

            // Use overlay frames if available, otherwise fallback to layout
            if let ruledView = ruledView {
                for index in 0..<paragraphs.count {
                    if let overlayFrame = ruledView.getOverlayFrame(forParagraphAtIndex: index) {
                        let adjustedFrame = overlayFrame.offsetBy(dx: -textView.textContainerInset.left, dy: -textView.textContainerInset.top)
                        paragraphRects.append(adjustedFrame)
                    } else {
                        // Fallback to layout-based detection
                        let rect = textView.layoutManager.boundingRect(
                            forGlyphRange: paragraphs[index].range,
                            in: textView.textContainer
                        )
                        paragraphRects.append(rect)
                    }
                }
            } else {
                // Fallback to layout-based detection
                for (_, paragraph) in paragraphs.enumerated() {
                    let rect = textView.layoutManager.boundingRect(
                        forGlyphRange: paragraph.range,
                        in: textView.textContainer
                    )
                    paragraphRects.append(rect)
                }
            }

            var targetIndex = 0
            for (index, rect) in paragraphRects.enumerated() {
                if adjustedLocation.y < rect.midY {
                    targetIndex = index
                    break
                } else if index == paragraphRects.count - 1 {
                    targetIndex = paragraphRects.count
                }
            }

            // Adjust for dragging paragraph removal
            if targetIndex > dragIndex {
                targetIndex -= 1
            }

            return max(0, min(targetIndex, paragraphs.count))
        }

        private func reorderParagraph(from sourceIndex: Int, to targetIndex: Int, textView: UITextView, isLiveDrag: Bool = false) {
            guard sourceIndex != targetIndex,
                  sourceIndex >= 0, sourceIndex < paragraphs.count,
                  targetIndex >= 0, targetIndex <= paragraphs.count else {
                return
            }

            // Reorder paragraphs array
            let movedParagraph = paragraphs[sourceIndex]
            var newParagraphs = paragraphs
            newParagraphs.remove(at: sourceIndex)
            newParagraphs.insert(movedParagraph, at: targetIndex)

            // Rebuild attributed string with new order
            let newAttributedString = rebuildAttributedString(from: newParagraphs)

            // Update text view
            textView.attributedText = newAttributedString
            parent.text = newAttributedString

            // Update paragraphs and overlays
            self.paragraphs = newParagraphs
            updateParagraphSpatialProperties()
            updateRuledViewFrame()

            // For live drag, don't reset the selection or cursor position
            if !isLiveDrag {
                // Ensure cursor is visible after final drop
                centerCursorInTextView()
            }
        }

        private func rebuildAttributedString(from paragraphs: [Paragraph]) -> NSAttributedString {
            let mutableAttributedString = NSMutableAttributedString()
            for (index, paragraph) in paragraphs.enumerated() {
                let isLast = index == paragraphs.count - 1
                var content = paragraph.content

                if isLast {
                    // On the last paragraph, ensure it does not end with a newline.
                    if content.string.hasSuffix("\n") {
                        content = content.attributedSubstring(from: NSRange(location: 0, length: content.length - 1))
                    }
                } else {
                    // On any other paragraph, ensure it ends with a newline.
                    if !content.string.hasSuffix("\n") {
                        let mutableContent = NSMutableAttributedString(attributedString: content)
                        var attributes: [NSAttributedString.Key: Any] = [: ]
                        if content.length > 0 {
                            attributes = content.attributes(at: content.length - 1, effectiveRange: nil)
                        } else if let textView = self.textView {
                            attributes = textView.typingAttributes
                        }
                        attributes[.paragraphStyle] = paragraph.paragraphStyle
                        mutableContent.append(NSAttributedString(string: "\n", attributes: attributes))
                        content = mutableContent
                    }
                }
                mutableAttributedString.append(content)
            }
            return mutableAttributedString
        }

        private func setDraggingSource(_ index: Int?) {
            ruledView?.setDraggingSourceIndex(index)
        }

        private func cancelDrag() {
            cleanupDrag()
        }

        private func cleanupDrag() {
            // Remove ghost view if it exists
            if showGhostOverlay {
                dragGhostView?.removeFromSuperview()
                dragGhostView = nil
            }

            // Stop auto-scrolling
            stopAutoScroll()

            // Restore original paragraph appearance
            setDraggingSource(nil)

            // Clear drag state
            draggingParagraphIndex = nil
            dragInitialLocation = nil
            dragTargetIndex = nil
            draggedParagraphID = nil
            initialTouchCount = 1
            isMultitouchDrag = false
        }

        // MARK: - Auto-Scrolling for Drag-to-Reorder
        private func startAutoScroll() {
            guard !isAutoScrolling, let _ = textView else { return }

            isAutoScrolling = true
            scrollDisplayLink = CADisplayLink(target: self, selector: #selector(updateAutoScroll))
            scrollDisplayLink?.add(to: .main, forMode: .common)

            // Haptic feedback for scroll start
            let scrollStartHaptic = UIImpactFeedbackGenerator(style: .light)
            scrollStartHaptic.impactOccurred()
        }

        private func stopAutoScroll() {
            isAutoScrolling = false
            scrollDisplayLink?.invalidate()
            scrollDisplayLink = nil
        }

        @objc private func updateAutoScroll() {
            guard let textView = textView, let location = dragInitialLocation else {
                stopAutoScroll()
                return
            }

            let scrollBounds = textView.bounds
            let contentOffset = textView.contentOffset
            let yPosition = location.y - contentOffset.y

            // Calculate scroll direction and speed
            var scrollDelta: CGFloat = 0

            // Top edge scrolling
            if yPosition < scrollEdgeThreshold {
                let distanceFromEdge = max(0, yPosition)
                let speedFactor = 1.0 - (distanceFromEdge / scrollEdgeThreshold)
                scrollDelta = -minScrollSpeed - (maxScrollSpeed - minScrollSpeed) * speedFactor
            }
            // Bottom edge scrolling
            else if yPosition > scrollBounds.height - scrollEdgeThreshold {
                let distanceFromEdge = max(0, scrollBounds.height - yPosition)
                let speedFactor = 1.0 - (distanceFromEdge / scrollEdgeThreshold)
                scrollDelta = minScrollSpeed + (maxScrollSpeed - minScrollSpeed) * speedFactor
            }

            if abs(scrollDelta) > 1 {
                let newOffset = CGPoint(
                    x: textView.contentOffset.x,
                    y: textView.contentOffset.y + scrollDelta / 60.0 // 60fps
                )

                // Clamp to valid range
                let maxOffset = max(0, textView.contentSize.height - textView.bounds.height + textView.adjustedContentInset.bottom)
                let clampedOffset = CGPoint(
                    x: newOffset.x,
                    y: max(-textView.adjustedContentInset.top, min(newOffset.y, maxOffset))
                )

                textView.setContentOffset(clampedOffset, animated: false)

                // Update drag location and check for new target
                let updatedLocation = CGPoint(x: location.x, y: location.y + scrollDelta / 60.0)
                dragInitialLocation = updatedLocation

                // Update target index based on new scroll position
                let newTargetIndex = calculateTargetIndex(for: updatedLocation, textView: textView)
                if newTargetIndex != dragTargetIndex {
                    let currentDragIndex = draggingParagraphIndex ?? 0
                    reorderParagraph(from: currentDragIndex, to: newTargetIndex, textView: textView, isLiveDrag: true)
                    draggingParagraphIndex = newTargetIndex
                    dragTargetIndex = newTargetIndex
                    setDraggingSource(newTargetIndex)
                    dragSelectionGenerator.selectionChanged()
                }
            } else {
                stopAutoScroll()
            }
        }

        private func checkAutoScroll(location: CGPoint, textView: UITextView) {
            let scrollBounds = textView.bounds
            let contentOffset = textView.contentOffset

            // Calculate location relative to visible bounds
            let visibleLocation = CGPoint(
                x: location.x,
                y: location.y - contentOffset.y
            )

            let shouldScrollTop = visibleLocation.y < scrollEdgeThreshold
            let shouldScrollBottom = visibleLocation.y > scrollBounds.height - scrollEdgeThreshold
            let shouldScroll = shouldScrollTop || shouldScrollBottom

            if shouldScroll && !isAutoScrolling {
                startAutoScroll()
            } else if !shouldScroll && isAutoScrolling {
                stopAutoScroll()
            }
        }

        // MARK: - Reply Gesture Handling

        @objc func handleSwipeToReplyGesture(_ gesture: UIPanGestureRecognizer) {
            guard let textView = textView, !isDragging, !isPinching else { return }
            let location = gesture.location(in: textView)

            switch gesture.state {
            case .began:
                handleReplyGestureBegan(location: location, textView: textView)
            case .changed:
                handleReplyGestureChanged(gesture: gesture, textView: textView)
            case .ended, .cancelled:
                handleReplyGestureEnded(gesture: gesture, textView: textView)
            default:
                break
            }
        }

        private func handleReplyGestureBegan(location: CGPoint, textView: UITextView) {
            guard replyGhostView == nil, let index = paragraphIndex(at: location, textView: textView) else { return }

            replyGestureParagraphIndex = index
            replyGestureInitialLocation = location

            // Create the ghost view from a snapshot of the original text
            guard let ghost = createReplyGhost(for: paragraphs[index], at: index, textView: textView) else { return }
            self.replyGhostView = ghost
            textView.addSubview(ghost)
        }

        @objc private func updateHoldProgress() {
            guard isHolding, let holdStartTime = holdStartTime else { return }

            let elapsed = CACurrentMediaTime() - holdStartTime
            let newProgress = min(elapsed / holdDuration, 1.0)

            // Check if we just reached 100%
            if newProgress >= 1.0 && holdProgress < 1.0 {
                holdHapticGenerator.impactOccurred()
            }

            holdProgress = newProgress

            // Update progress indicator without implicit animations
            if let progressContainer = holdProgressView,
               let progressLayer = progressContainer.layer.sublayers?.first as? CAShapeLayer {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                progressLayer.strokeEnd = holdProgress
                CATransaction.commit()
            }
        }

        private func handleReplyGestureChanged(gesture: UIPanGestureRecognizer, textView: UITextView) {
            guard let ghostView = replyGhostView, let paragraphIndex = replyGestureParagraphIndex else { return }

            let translation = gesture.translation(in: textView)

            // Check if this is a horizontal swipe on the first movement
            if !isHorizontalSwipe {
                let horizontalMovement = abs(translation.x)
                let verticalMovement = abs(translation.y)

                // Cancel if vertical movement is dominant
                if verticalMovement > horizontalMovement && verticalMovement > 10 {
                    cleanupReplyGesture()
                    return
                }

                // Mark as horizontal swipe and determine direction
                if horizontalMovement > verticalMovement {
                    isHorizontalSwipe = true
                    swipeDirection = translation.x > 0 ? .right : .left

                    // Create overlay after direction is determined, insert below ghost
                    if let ghostView = replyGhostView {
                        createReplyOverlay(for: paragraphs[paragraphIndex], at: paragraphIndex, textView: textView)
                        if let overlay = replyOverlayView {
                            textView.insertSubview(overlay, belowSubview: ghostView)
                        }
                    }
                }
            }

            // Only proceed if it's a horizontal swipe
            guard isHorizontalSwipe else {
                cleanupReplyGesture()
                return
            }

            let horizontalTranslation: CGFloat
            if swipeDirection == .right {
                horizontalTranslation = min(max(0, translation.x), replyGestureThreshold)
            } else {
                horizontalTranslation = max(min(0, translation.x), -replyGestureThreshold)
            }

            // Apply 1:1 translation to ghost view (capped at threshold)
            ghostView.transform = CGAffineTransform(translationX: horizontalTranslation, y: 0)

            // Handle hold-to-confirm
            let percentage = abs(horizontalTranslation) / replyGestureThreshold
            let isAboveThreshold = percentage >= 1.0

            if let overlay = replyOverlayView, let iconView = overlay.subviews.first {
                let iconAlpha = min(percentage, 1.0)
                iconView.alpha = iconAlpha

                if let progressContainer = self.holdProgressView {
                    progressContainer.alpha = iconAlpha
                }

                // Handle hold-to-confirm for delete
                if swipeDirection == .left {
                    let scale = 1.0 + (percentage) * 0.1 // Scale up to 1.1
                    iconView.transform = CGAffineTransform(scaleX: scale, y: scale)

                    if isAboveThreshold {
                        if !isHolding {
                            // Start hold
                            isHolding = true
                            holdStartTime = CACurrentMediaTime()
                            holdProgress = 0.0

                            // Start display link for continuous updates
                            holdDisplayLink?.invalidate()
                            holdDisplayLink = CADisplayLink(target: self, selector: #selector(updateHoldProgress))
                            holdDisplayLink?.add(to: .main, forMode: .common)
                        }
                    } else {
                        // Reset hold state
                        if isHolding {
                            isHolding = false
                            holdStartTime = nil
                            holdProgress = 0.0

                            // Stop display link
                            holdDisplayLink?.invalidate()
                            holdDisplayLink = nil

                            // Reset progress indicator with smooth rewind animation
                            if let progressContainer = holdProgressView,
                               let progressLayer = progressContainer.layer.sublayers?.first as? CAShapeLayer {
                                let animation = CABasicAnimation(keyPath: "strokeEnd")
                                animation.toValue = 0.0
                                animation.duration = 0.2
                                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                                progressLayer.add(animation, forKey: "strokeEndAnimation")
                                progressLayer.strokeEnd = 0.0
                            }
                        }
                    }
                } else {
                    let scale = 1.0 + (percentage) * 0.5 // Scale up to 1.5
                    iconView.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
            }

            // Track threshold crossings for haptic feedback
            let wasAboveThreshold = hasTriggeredReplyHaptic
            if isAboveThreshold && !wasAboveThreshold {
                replyGestureHapticGenerator.impactOccurred() // Trigger haptic for both directions
                hasTriggeredReplyHaptic = true
            } else if !isAboveThreshold && wasAboveThreshold {
                hasTriggeredReplyHaptic = false
            }
        }

        private func handleReplyGestureEnded(gesture: UIPanGestureRecognizer, textView: UITextView) {
            guard replyGhostView != nil else { return }
            let translation = gesture.translation(in: textView)
            let horizontalTranslation = swipeDirection == .right
                ? min(max(0, translation.x), replyGestureThreshold)
                : max(min(0, translation.x), -replyGestureThreshold)

            // Check hold-to-confirm completion for delete
            if isHorizontalSwipe {
                if swipeDirection == .right {
                    // Reply uses immediate confirmation
                    if abs(horizontalTranslation) >= replyGestureThreshold {
                        triggerReplyAction()
                    }
                } else if swipeDirection == .left {
                    // Delete uses hold-to-confirm
                    if holdProgress >= 1.0 {
                        triggerDeleteAction()
                    }
                }
            }

            // Cleanup
            cleanupReplyGesture()
        }

        private func createReplyGhost(for paragraph: Paragraph, at index: Int, textView: UITextView) -> UIView? {
            guard let snapshotRect = ruledView?.getOverlayFrame(forParagraphAtIndex: index) else { return nil }
            guard let snapshotView = textView.resizableSnapshotView(from: snapshotRect, afterScreenUpdates: true, withCapInsets: .zero) else { return nil }

            let ghostContainerView = UIView(frame: snapshotRect)

            snapshotView.frame = ghostContainerView.bounds
            ghostContainerView.addSubview(snapshotView)

            return ghostContainerView
        }

        private func createCircularProgressView() -> UIView {
            let size: CGFloat = 52
            let progressView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))

            // Create circular progress layer
            let progressLayer = CAShapeLayer()
            let center = CGPoint(x: size/2, y: size/2)
            let radius: CGFloat = 26
            let startAngle = -CGFloat.pi / 2 // Start at top
            let endAngle = startAngle + 2 * CGFloat.pi

            let circularPath = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )

            progressLayer.path = circularPath.cgPath
            progressLayer.fillColor = UIColor.clear.cgColor
            progressLayer.strokeColor = UIColor.systemRed.cgColor
            progressLayer.lineWidth = 3
            progressLayer.strokeEnd = 0
            progressLayer.lineCap = .round

            progressView.layer.addSublayer(progressLayer)
            progressView.tag = 1001 // For later reference

            return progressView
        }

        private func createReplyOverlay(for paragraph: Paragraph, at index: Int, textView: UITextView) {
            guard let overlayRect = ruledView?.getOverlayFrame(forParagraphAtIndex: index) else { return }

            let overlayView = UIView(frame: overlayRect)
            // Use systemBackground to ensure it's opaque and covers the text
            overlayView.backgroundColor = .systemBackground
            overlayView.layer.cornerRadius = ruledView?.overlayCornerRadius ?? 20.0
            overlayView.layer.masksToBounds = true

            // Determine icon and position based on swipe direction
            let iconName: String
            let iconColor: UIColor
            let horizontalPosition: NSLayoutXAxisAnchor
            let horizontalConstant: CGFloat

            if swipeDirection == .left {
                iconName = "trash"
                iconColor = .systemRed
                horizontalPosition = overlayView.trailingAnchor
                horizontalConstant = -52 // Move further from edge to prevent clipping
            } else {
                iconName = "plus"
                iconColor = .systemGreen
                horizontalPosition = overlayView.leadingAnchor
                horizontalConstant = 20 // Move further from edge to prevent clipping
            }

            let iconView = UIHostingController(rootView:
                Image(systemName: iconName)
                    .font(.title)
                    .foregroundColor(Color(iconColor))
            ).view!
            iconView.backgroundColor = .clear
            iconView.translatesAutoresizingMaskIntoConstraints = false
            overlayView.addSubview(iconView)

            // Position the icon with proper padding from edges
            NSLayoutConstraint.activate([
                iconView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
                iconView.leadingAnchor.constraint(equalTo: horizontalPosition, constant: horizontalConstant)
            ])

            // Add circular progress indicator for delete confirmation
            if swipeDirection == .left {
                let progressContainer = createCircularProgressView()
                progressContainer.translatesAutoresizingMaskIntoConstraints = false
                overlayView.addSubview(progressContainer)

                // Position the progress indicator with manual offsets
                let horizontalOffset: CGFloat = -62.5 // Adjust this to move left/right
                let verticalOffset: CGFloat = -26 // Adjust this to move up/down

                NSLayoutConstraint.activate([
                    progressContainer.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: verticalOffset),
                    progressContainer.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: horizontalOffset)
                ])

                holdProgressView = progressContainer
            }

            replyOverlayView = overlayView
        }

        private func triggerReplyAction() {
            guard let textView = textView,
                  let paragraphIndex = replyGestureParagraphIndex,
                  paragraphIndex < paragraphs.count else { return }

            replyGestureHapticGenerator.impactOccurred()

            let originalParagraph = paragraphs[paragraphIndex]
            let insertLocation = originalParagraph.range.location + originalParagraph.range.length

            // Determine spacing based on original paragraph spacing
            let originalSpacing = originalParagraph.paragraphStyle.paragraphSpacing
            let isOriginallyUnrelated = abs(originalSpacing - AppSettings.unrelatedParagraphSpacing) < spacingTolerance

            // Create new paragraph style - use unrelated if original was unrelated, otherwise related
            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.setParagraphStyle(originalParagraph.paragraphStyle)
            newParagraphStyle.paragraphSpacing = isOriginallyUnrelated ? AppSettings.unrelatedParagraphSpacing : AppSettings.relatedParagraphSpacing

            // Use the same font as the original paragraph or fallback to typing attributes
            let originalAttributes: [NSAttributedString.Key: Any]
            if originalParagraph.content.length > 0 {
                originalAttributes = originalParagraph.content.attributes(at: 0, effectiveRange: nil)
            } else {
                originalAttributes = textView.typingAttributes
            }
            let font = originalAttributes[.font] as? UIFont ?? textView.typingAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)

            let newAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: newParagraphStyle,
                .foregroundColor: UIColor.label
            ]

            let newParagraph = NSAttributedString(string: "\n", attributes: newAttributes)

            // Insert the new paragraph
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableText.insert(newParagraph, at: insertLocation)

            // Update the new paragraph's spacing
            let newParagraphRange = NSRange(location: insertLocation, length: 1)
            let finalNewParagraphStyle = NSMutableParagraphStyle()
            finalNewParagraphStyle.setParagraphStyle(originalParagraph.paragraphStyle)
            finalNewParagraphStyle.paragraphSpacing = isOriginallyUnrelated ?
                                                      AppSettings.unrelatedParagraphSpacing :
                                                      AppSettings.relatedParagraphSpacing
            mutableText.addAttribute(.paragraphStyle, value: finalNewParagraphStyle, range: newParagraphRange)

            // Update the original paragraph's spacing to related
            if isOriginallyUnrelated {
                let originalRange = originalParagraph.range
                let originalStyle = NSMutableParagraphStyle()
                originalStyle.setParagraphStyle(originalParagraph.paragraphStyle)
                originalStyle.paragraphSpacing = AppSettings.relatedParagraphSpacing
                mutableText.addAttribute(.paragraphStyle, value: originalStyle, range: originalRange)
            }

            // Update text view and state
            textView.attributedText = mutableText
            parent.text = mutableText

            // Handle cursor positioning for edge case of last paragraph
            let isLastParagraph = paragraphIndex == paragraphs.count - 1
            let cursorPosition = isLastParagraph ? insertLocation + 1 : insertLocation
            textView.selectedRange = NSRange(location: cursorPosition, length: 0)
            parent.selectedRange = textView.selectedRange

            // Update paragraphs and ensure cursor is visible
            self.parseAttributedText(mutableText)
            DispatchQueue.main.async {
                self.centerCursorInTextView()
                // Show keyboard after caret is positioned
                textView.becomeFirstResponder()
            }
        }

        private func triggerDeleteAction() {
            guard let textView = textView,
                  let paragraphIndex = replyGestureParagraphIndex,
                  paragraphIndex < paragraphs.count else { return }

            // Use medium haptic for delete confirmation
            let deleteHapticGenerator = UIImpactFeedbackGenerator(style: .medium)
            deleteHapticGenerator.impactOccurred()

            let paragraphToDelete = paragraphs[paragraphIndex]
            let deleteRange = paragraphToDelete.range

            // Don't allow deleting the last paragraph - just clear it instead
            if paragraphs.count == 1 {
                let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
                mutableText.replaceCharacters(in: deleteRange, with: "")

                // Add an empty paragraph to maintain structure
                let emptyParagraphStyle = NSMutableParagraphStyle()
                emptyParagraphStyle.paragraphSpacing = parent.settings.defaultParagraphSpacing
                let emptyAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .paragraphStyle: emptyParagraphStyle,
                    .foregroundColor: UIColor.label
                ]
                let emptyParagraph = NSAttributedString(string: "", attributes: emptyAttributes)
                mutableText.append(emptyParagraph)

                textView.attributedText = mutableText
                parent.text = mutableText
                textView.selectedRange = NSRange(location: 0, length: 0)
                parent.selectedRange = textView.selectedRange
            } else {
                // Use rebuild logic for proper paragraph handling
                var newParagraphs = paragraphs
                newParagraphs.remove(at: paragraphIndex)

                // Rebuild the entire text using proven logic
                let newAttributedString = rebuildAttributedString(from: newParagraphs)

                textView.attributedText = newAttributedString
                parent.text = newAttributedString

                // Position cursor appropriately based on deletion
                let cursorLocation = min(deleteRange.location, newAttributedString.length)
                textView.selectedRange = NSRange(location: cursorLocation, length: 0)
                parent.selectedRange = textView.selectedRange
            }

            // Update paragraphs and ensure cursor is visible
            self.parseAttributedText(textView.attributedText)
        }

        private func cleanupReplyGesture() {
            func cleanup() {
                self.replyGhostView?.removeFromSuperview()
                self.replyOverlayView?.removeFromSuperview()
                self.replyGhostView = nil
                self.replyOverlayView = nil
                self.replyGestureParagraphIndex = nil
                self.replyGestureInitialLocation = nil
                self.hasTriggeredReplyHaptic = false
                self.isHorizontalSwipe = false
                self.swipeDirection = .none

                // Reset hold-to-confirm state
                self.isHolding = false
                self.holdStartTime = nil
                self.holdProgress = 0.0
                self.holdProgressView = nil

                // Stop display link
                self.holdDisplayLink?.invalidate()
                self.holdDisplayLink = nil
            }

            guard let ghostView = replyGhostView, let overlayView = replyOverlayView else {
                // Fallback to immediate cleanup if views don't exist
                cleanup()
                return
            }

            // Spring animation for ghost return to original position
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    ghostView.transform = CGAffineTransform.identity
                    overlayView.subviews.first?.alpha = 0.0
                    overlayView.subviews.first?.transform = .identity

                    if let progressContainer = self.holdProgressView {
                        progressContainer.alpha = 0.0
                    }
                },
                completion: { _ in
                    cleanup()
                }
            )
        }
    }
}

extension RichTextEditor.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
