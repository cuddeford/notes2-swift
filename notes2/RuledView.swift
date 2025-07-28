import UIKit

class RuledView: UIView {
    weak var textView: UITextView?

    private var paragraphOverlays: [CAShapeLayer] = []
    private var targetIndicatorLayers: [CAShapeLayer] = []
    private var dragState: DragState = .none

    enum DragState {
        case none
        case dragging(sourceIndex: Int, targetIndex: Int?)
    }

    // Haptic feedback state for border thickness
    private var hapticBorderStates: [NSRange: HapticBorderState] = [:]
    private let baseBorderWidth: CGFloat = 2.0
    private let heavyHapticAddition: CGFloat = 20.0
    private let lightHapticAddition: CGFloat = 6.0
    private let animationDuration: CFTimeInterval = 0.15

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        registerForTraitChanges()
        registerForOrientationChanges()
        registerForSidebarChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        registerForTraitChanges()
        registerForOrientationChanges()
        registerForSidebarChanges()
    }

    private func setupLayers() {
        self.backgroundColor = .clear
        self.isOpaque = false
    }

    // listen for dark mode change to refresh the UILabel colors on the overlays
    private func registerForTraitChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (view: RuledView, previousTraitCollection: UITraitCollection?) in
            guard let strongSelf = self else { return }
            if strongSelf.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                strongSelf.reflowText()
            }
        }
    }

    // listen for orientation changes to reflow the textView
    private func registerForOrientationChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    private func registerForSidebarChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sidebarStateChanged),
            name: .sidebarStateChanged,
            object: nil
        )
    }

    @objc private func orientationChanged() {
        // Use a small delay to ensure layout is complete after rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.reflowText()
        }
    }

    @objc private func sidebarStateChanged() {
        // Force layout pass and then reflow
        DispatchQueue.main.async { [weak self] in
            self?.textView?.layoutIfNeeded()
            self?.reflowText()
        }

        // Additional attempt, delay for layout completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.textView?.layoutIfNeeded()
            self?.reflowText()
        }
    }

    private func reflowText() {
        guard let coordinator = textView?.delegate as? RichTextEditor.Coordinator,
              let textView = textView else {
            return
        }

        updateAllParagraphOverlays(
            paragraphs: coordinator.paragraphs,
            textView: textView,
            activePinchedPairs: coordinator.activePinchedPairs
        )
    }

    func updateAllParagraphOverlays(paragraphs: [Paragraph], textView: UITextView, activePinchedPairs: [NSRange: (indices: [Int], timestamp: CFTimeInterval)] = [:], currentGestureDetent: CGFloat? = nil, currentGestureRange: NSRange? = nil) {
        let inset = textView.textContainerInset
        let cornerRadius = 20.0

        // Remove excess layers
        if paragraphOverlays.count > paragraphs.count {
            for i in paragraphs.count..<paragraphOverlays.count {
                paragraphOverlays[i].removeFromSuperlayer()
            }
            paragraphOverlays.removeLast(paragraphOverlays.count - paragraphs.count)
        }

        let overlayPaddingHorizontal = 15.0
        let overlayPaddingVertical = overlayPaddingHorizontal / 2.0
        // Update existing layers or create new ones
        for (index, paragraph) in paragraphs.enumerated() {
            let rect = textView.layoutManager.boundingRect(forGlyphRange: paragraph.range, in: textView.textContainer)
            var drawingRect = rect.offsetBy(dx: inset.left, dy: inset.top).insetBy(dx: -overlayPaddingHorizontal, dy: -overlayPaddingVertical)

            if index == paragraphs.count - 2 {
                if paragraphs[paragraphs.count - 1].content.string.isEmpty {
                    drawingRect.size.height -= paragraph.paragraphStyle.paragraphSpacing + textView.font!.lineHeight
                    drawingRect.size.width -= 5.0
                    drawingRect.origin.x += 5.0
                }
            }

            var path = UIBezierPath(roundedRect: drawingRect, cornerRadius: cornerRadius).cgPath

            if index == paragraphs.count - 1 {
                let lastIsEmpty = paragraph.content.string.isEmpty
                // force paragraph blocks when single lines, rather than inline
                var width = textView.textContainer.size.width + overlayPaddingHorizontal
                if paragraphs.indices.contains(index - 1) {
                    width = textView.layoutManager.boundingRect(forGlyphRange: paragraphs[index - 1].range, in: textView.textContainer).offsetBy(dx: inset.left, dy: inset.top).insetBy(dx: -overlayPaddingHorizontal, dy: -overlayPaddingVertical).width - (lastIsEmpty ? 5.0 : 0)
                }

                let blockRect = CGRect(
                    x: drawingRect.minX,
                    y: drawingRect.minY,
                    width: width,
                    height: drawingRect.height,
                )

                path = UIBezierPath(roundedRect: blockRect, cornerRadius: cornerRadius).cgPath
            }

            // weird little hack for height spacing on the penultimate paragraph
            if index == paragraphs.count - 2 {
                if paragraphs.indices.contains(index + 1) {
                    let lastIsEmpty = paragraphs[index + 1].content.string.isEmpty

                    if lastIsEmpty {
                        let heightFixRect = CGRect(
                            x: drawingRect.minX,
                            y: drawingRect.minY,
                            width: drawingRect.width,
                            height: drawingRect.height - 0.5,
                        )

                        path = UIBezierPath(roundedRect: heightFixRect, cornerRadius: cornerRadius).cgPath
                    }
                }
            }

            // Check if this paragraph is part of any active pinched pair
            var isPinched = false
            var useCurrentDetent = false
            var latestTimestamp: CFTimeInterval = -1

            for (range, pairInfo) in activePinchedPairs {
                if pairInfo.indices.contains(index) {
                    if pairInfo.timestamp > latestTimestamp {
                        isPinched = true
                        latestTimestamp = pairInfo.timestamp
                        useCurrentDetent = (range == currentGestureRange)
                    }
                }
            }

            let detent: CGFloat
            if isPinched {
                if useCurrentDetent {
                    detent = currentGestureDetent ?? paragraph.paragraphStyle.paragraphSpacing
                } else {
                    // This is part of a pair, but not the one being actively gestured.
                    // Find the primary paragraph of the pair to determine the color.
                    var primaryParagraphDetent = paragraph.paragraphStyle.paragraphSpacing
                    var latestTimestamp: CFTimeInterval = -1

                    for (_, pairInfo) in activePinchedPairs {
                        if pairInfo.indices.contains(index) {
                            if pairInfo.timestamp > latestTimestamp {
                                latestTimestamp = pairInfo.timestamp
                                let primaryIndex = min(pairInfo.indices[0], pairInfo.indices[1])
                                if paragraphs.indices.contains(primaryIndex) {
                                    primaryParagraphDetent = paragraphs[primaryIndex].paragraphStyle.paragraphSpacing
                                }
                            }
                        }
                    }
                    detent = primaryParagraphDetent
                }
            } else {
                detent = paragraph.paragraphStyle.paragraphSpacing
            }

            let (fill, stroke) = colors(for: detent, isPinched: isPinched)
            let borderWidth = self.borderWidth(for: paragraphs[index].range)

            if index < paragraphOverlays.count {
                // Update existing layer
                paragraphOverlays[index].path = path
                paragraphOverlays[index].fillColor = fill.cgColor
                paragraphOverlays[index].strokeColor = stroke.cgColor
                paragraphOverlays[index].opacity = 1
                paragraphOverlays[index].lineWidth = borderWidth
            } else {
                // Create new layer
                let newLayer = CAShapeLayer()
                newLayer.lineWidth = borderWidth
                newLayer.fillColor = UIColor.clear.cgColor
                newLayer.path = path
                newLayer.fillColor = fill.cgColor
                newLayer.strokeColor = stroke.cgColor
                newLayer.opacity = 1
                layer.addSublayer(newLayer)
                paragraphOverlays.append(newLayer)
            }
        }
    }

    func hideAllParagraphOverlays() {
        for layer in paragraphOverlays {
            layer.opacity = 0
        }
    }

    // MARK: - Drag-to-Reorder Visual Support

    func updateParagraphOverlayOpacity(index: Int, opacity: Float) {
        guard index < paragraphOverlays.count else { return }
        paragraphOverlays[index].opacity = opacity
    }

    func updateTargetIndicators(targetIndex: Int?) {
        // Clear existing target indicators
        for layer in targetIndicatorLayers {
            layer.removeFromSuperlayer()
        }
        targetIndicatorLayers.removeAll()

        guard let textView = textView,
              let coordinator = textView.delegate as? RichTextEditor.Coordinator,
              let targetIndex = targetIndex else { return }

        let paragraphs = coordinator.paragraphs
        let inset = textView.textContainerInset
        let indicatorHeight: CGFloat = 4
        let indicatorWidth: CGFloat = textView.textContainer.size.width
        let cornerRadius: CGFloat = 2

        // Calculate position for target indicator
        var yPosition: CGFloat

        if targetIndex == 0 {
            // Before first paragraph
            if paragraphs.count > 0 {
                let firstParagraph = paragraphs[0]
                let rect = textView.layoutManager.boundingRect(forGlyphRange: firstParagraph.range, in: textView.textContainer)
                yPosition = rect.origin.y + inset.top - 10
            } else {
                yPosition = inset.top
            }
        } else if targetIndex == paragraphs.count {
            // After last paragraph
            if paragraphs.count > 0 {
                let lastParagraph = paragraphs[paragraphs.count - 1]
                let rect = textView.layoutManager.boundingRect(forGlyphRange: lastParagraph.range, in: textView.textContainer)
                yPosition = rect.origin.y + rect.height + inset.top + 10
            } else {
                yPosition = inset.top
            }
        } else {
            // Between paragraphs
            let prevParagraph = paragraphs[targetIndex - 1]
            let prevRect = textView.layoutManager.boundingRect(forGlyphRange: prevParagraph.range, in: textView.textContainer)
            yPosition = prevRect.origin.y + prevRect.height + inset.top + (prevParagraph.paragraphStyle.paragraphSpacing / 2)
        }

        let indicatorRect = CGRect(
            x: inset.left,
            y: yPosition - indicatorHeight / 2,
            width: indicatorWidth,
            height: indicatorHeight
        )

        let indicatorLayer = CAShapeLayer()
        indicatorLayer.path = UIBezierPath(roundedRect: indicatorRect, cornerRadius: cornerRadius).cgPath
        indicatorLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        indicatorLayer.opacity = 0

        layer.addSublayer(indicatorLayer)
        targetIndicatorLayers.append(indicatorLayer)

        // Animate appearance
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.2
        indicatorLayer.add(animation, forKey: "fadeIn")
        indicatorLayer.opacity = 1
    }

    func clearTargetIndicators() {
        for layer in targetIndicatorLayers {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.duration = 0.2
            layer.add(animation, forKey: "fadeOut")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                layer.removeFromSuperlayer()
            }
        }
        targetIndicatorLayers.removeAll()
    }

    func triggerHapticFeedback(for range: NSRange, type: HapticType) {
        // Apply haptic state to this paragraph
        hapticBorderStates[range] = HapticBorderState(timestamp: CACurrentMediaTime(), type: type)

        // Also apply to paired paragraph if this is part of a pinched pair
        if let coordinator = textView?.delegate as? RichTextEditor.Coordinator {
            for (pairRange, pairInfo) in coordinator.activePinchedPairs {
                if pairRange == range, pairInfo.indices.count == 2 {
                    // Find the other paragraph in the pair and apply the same haptic state
                    for index in pairInfo.indices {
                        if index < coordinator.paragraphs.count {
                            let otherRange = coordinator.paragraphs[index].range
                            if otherRange != range {
                                hapticBorderStates[otherRange] = HapticBorderState(timestamp: CACurrentMediaTime(), type: type)
                            }
                        }
                    }
                    break
                }
            }
        }

        // Update overlays to reflect new border thickness
        if let coordinator = textView?.delegate as? RichTextEditor.Coordinator {
            updateAllParagraphOverlays(
                paragraphs: coordinator.paragraphs,
                textView: textView!,
                activePinchedPairs: coordinator.activePinchedPairs,
                currentGestureDetent: nil,
                currentGestureRange: nil
            )
        }

        // Schedule cleanup after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.clearHapticState(for: range)
        }
    }

    private func clearHapticState(for range: NSRange) {
        hapticBorderStates.removeValue(forKey: range)

        // Also clear paired paragraph's haptic state
        if let coordinator = textView?.delegate as? RichTextEditor.Coordinator {
            for (pairRange, pairInfo) in coordinator.activePinchedPairs {
                if pairRange == range, pairInfo.indices.count == 2 {
                    for index in pairInfo.indices {
                        if index < coordinator.paragraphs.count {
                            let otherRange = coordinator.paragraphs[index].range
                            hapticBorderStates.removeValue(forKey: otherRange)
                        }
                    }
                    break
                }
            }
        }

        if let coordinator = textView?.delegate as? RichTextEditor.Coordinator {
            updateAllParagraphOverlays(
                paragraphs: coordinator.paragraphs,
                textView: textView!,
                activePinchedPairs: coordinator.activePinchedPairs,
                currentGestureDetent: nil,
                currentGestureRange: nil
            )
        }
    }

    private func borderWidth(for range: NSRange) -> CGFloat {
        guard let hapticState = hapticBorderStates[range] else {
            return baseBorderWidth
        }

        let elapsed = CACurrentMediaTime() - hapticState.timestamp
        if elapsed >= animationDuration {
            return baseBorderWidth
        }

        // Ensure deterministic progress calculation
        let clampedElapsed = min(elapsed, animationDuration)
        let progress = CGFloat(clampedElapsed / animationDuration)

        // Use existing easing functions for smooth pulse animation
        let pulseProgress: CGFloat
        if progress <= 0.5 {
            // Going up: use easeOutBack for a natural ramp-up to exactly 1.0 at 50%
            pulseProgress = EasingFunctions.easeOutBack(progress * 2.0)
        } else {
            // Going down: use easeInOutQuad for smooth decay to exactly 0.0 at 100%
            pulseProgress = EasingFunctions.easeInOutQuad((1.0 - progress) * 2.0)
        }

        let additionalWidth: CGFloat
        switch hapticState.type {
        case .heavy:
            additionalWidth = heavyHapticAddition * pulseProgress
        case .light:
            additionalWidth = lightHapticAddition * pulseProgress
        }

        return baseBorderWidth + additionalWidth
    }

    private func colors(for detent: CGFloat? = nil, isPinched: Bool = false) -> (fill: UIColor, stroke: UIColor) {
        guard isPinched else {
            // Default color for all non-pinched paragraphs
            return (UIColor.label.withAlphaComponent(0.05), UIColor.clear)
        }

        // Dynamic colors for pinched paragraphs based on their relationship
        // Both paragraphs in the pair should show the same color
        switch detent {
        case AppSettings.relatedParagraphSpacing:
            return (UIColor.green.withAlphaComponent(0.25), .green)
        case AppSettings.unrelatedParagraphSpacing:
            return (UIColor.yellow.withAlphaComponent(0.25), .yellow)
        default:
            // Intermediate spacing during gesture
            let isRelated = (detent ?? 0) < (AppSettings.relatedParagraphSpacing + AppSettings.unrelatedParagraphSpacing) / 2
            return isRelated
                ? (UIColor.green.withAlphaComponent(0.15), UIColor.green.withAlphaComponent(0.8))
                : (UIColor.yellow.withAlphaComponent(0.15), UIColor.yellow.withAlphaComponent(0.8))
        }
    }

    override func draw(_ rect: CGRect) {
        if (!AppSettings.showRuledLines) {
            return
        }

        guard let context = UIGraphicsGetCurrentContext(), let textView = textView else { return }

        let inset = textView.textContainerInset
        let lineColor = UIColor.lightGray.withAlphaComponent(0.3)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1.0)

        let layoutManager = textView.layoutManager
        let textStorage = textView.textStorage

        var glyphIndex = 0
        while glyphIndex < layoutManager.numberOfGlyphs {
            var glyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &glyphRange)
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            var lineY = lineRect.origin.y + lineRect.height + inset.top

            if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: characterRange.location, effectiveRange: nil) as? NSParagraphStyle {
                let paragraphRange = (textStorage.string as NSString).paragraphRange(for: characterRange)
                let isLastLineOfParagraph = NSMaxRange(characterRange) == NSMaxRange(paragraphRange)
                if isLastLineOfParagraph {
                    lineY -= paragraphStyle.paragraphSpacing
                }
            }

            context.move(to: CGPoint(x: self.bounds.minX, y: lineY))
            context.addLine(to: CGPoint(x: self.bounds.maxX, y: lineY))
            context.strokePath()

            glyphIndex = NSMaxRange(glyphRange)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
