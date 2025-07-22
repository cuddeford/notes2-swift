import UIKit

class RuledView: UIView {
    weak var textView: UITextView?

    private var paragraphOverlays: [CAShapeLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        self.backgroundColor = .clear
        self.isOpaque = false
    }

    func updateAllParagraphOverlays(paragraphs: [Paragraph], textView: UITextView, activePinchedPairs: [NSRange: (indices: [Int], timestamp: CFTimeInterval)] = [:], currentGestureDetent: CGFloat? = nil, currentGestureRange: NSRange? = nil) {
        let inset = textView.textContainerInset
        let cornerRadius = 10.0

        // Remove excess layers
        if paragraphOverlays.count > paragraphs.count {
            for i in paragraphs.count..<paragraphOverlays.count {
                paragraphOverlays[i].removeFromSuperlayer()
            }
            paragraphOverlays.removeLast(paragraphOverlays.count - paragraphs.count)
        }

        // Update existing layers or create new ones
        for (index, paragraph) in paragraphs.enumerated() {
            let rect = textView.layoutManager.boundingRect(forGlyphRange: paragraph.range, in: textView.textContainer)
            var drawingRect = rect.offsetBy(dx: inset.left, dy: inset.top)

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
                var width = textView.textContainer.size.width - 10.0
                if paragraphs.indices.contains(index - 1) {
                    width = textView.layoutManager.boundingRect(forGlyphRange: paragraphs[index - 1].range, in: textView.textContainer).offsetBy(dx: inset.left, dy: inset.top).width - (lastIsEmpty ? 5.0 : 0)
                }

                let blockRect = CGRect(
                    x: drawingRect.minX,
                    y: drawingRect.minY,
                    width: width,
                    height: drawingRect.height,
                )

                path = UIBezierPath(roundedRect: blockRect, cornerRadius: cornerRadius).cgPath
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

                    for (range, pairInfo) in activePinchedPairs {
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

            if index < paragraphOverlays.count {
                // Update existing layer
                paragraphOverlays[index].path = path
                paragraphOverlays[index].fillColor = fill.cgColor
                paragraphOverlays[index].strokeColor = stroke.cgColor
                paragraphOverlays[index].opacity = 1
            } else {
                // Create new layer
                let newLayer = CAShapeLayer()
                newLayer.lineWidth = 2.0
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

    private func colors(for detent: CGFloat? = nil, isPinched: Bool = false) -> (fill: UIColor, stroke: UIColor) {
        guard isPinched else {
            // Default color for all non-pinched paragraphs
            return (UIColor.label.withAlphaComponent(0.05), UIColor.label.withAlphaComponent(0.1))
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
}
