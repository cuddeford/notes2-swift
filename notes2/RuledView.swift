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

    func updateAllParagraphOverlays(paragraphs: [Paragraph], textView: UITextView) {
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
            let drawingRect = rect.offsetBy(dx: inset.left, dy: inset.top)
            let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: cornerRadius).cgPath

            let (fill, stroke) = colors(for: AppSettings.shared.defaultParagraphSpacing, default: .blue)

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

    private func colors(for detent: CGFloat, default defaultColor: UIColor) -> (fill: UIColor, stroke: UIColor) {
        switch detent {
        case AppSettings.relatedParagraphSpacing:
            return (UIColor.green.withAlphaComponent(0.25), .green)
        case AppSettings.unrelatedParagraphSpacing:
            return (UIColor.yellow.withAlphaComponent(0.1), UIColor.yellow.withAlphaComponent(0.25))
        default:
            return (defaultColor.withAlphaComponent(0.25), defaultColor)
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
