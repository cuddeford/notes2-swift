import UIKit

class RuledView: UIView {
    weak var textView: UITextView?

    private let paragraphOverlay1 = CAShapeLayer()
    private let paragraphOverlay2 = CAShapeLayer()
    private let unrelatedTextLayer = CATextLayer()
    private let relatedTextLayer = CATextLayer()

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

        // Setup paragraph overlays
        [paragraphOverlay1, paragraphOverlay2].forEach {
            $0.lineWidth = 2.0
            $0.fillColor = UIColor.clear.cgColor
            layer.addSublayer($0)
        }

        // Setup text layer
        unrelatedTextLayer.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        unrelatedTextLayer.fontSize = 14
        unrelatedTextLayer.foregroundColor = UIColor.lightGray.cgColor
        unrelatedTextLayer.string = "Unrelated paragraphs"
        unrelatedTextLayer.alignmentMode = .center
        unrelatedTextLayer.contentsScale = UIScreen.main.scale
        unrelatedTextLayer.isHidden = true
        layer.addSublayer(unrelatedTextLayer)

        // Setup related text layer
        relatedTextLayer.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        relatedTextLayer.fontSize = 14
        relatedTextLayer.foregroundColor = UIColor.lightGray.cgColor
        relatedTextLayer.string = "Related paragraphs"
        relatedTextLayer.alignmentMode = .center
        relatedTextLayer.contentsScale = UIScreen.main.scale
        relatedTextLayer.isHidden = true
        layer.addSublayer(relatedTextLayer)
    }

    func updateOverlays(rect1: CGRect?, rect2: CGRect?, detent: CGFloat, animated: Bool) {
        let inset = textView?.textContainerInset ?? .zero

        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.2 : 0)

        // Update first overlay
        if let rect = rect1 {
            let drawingRect = rect.offsetBy(dx: inset.left, dy: inset.top)
            let cornerRadius = 10.0
            paragraphOverlay1.path = UIBezierPath(roundedRect: drawingRect, cornerRadius: cornerRadius).cgPath

            let (fill, stroke) = colors(for: detent, default: .red)
            paragraphOverlay1.fillColor = fill.cgColor
            paragraphOverlay1.strokeColor = stroke.cgColor
            paragraphOverlay1.opacity = 1
        } else {
            paragraphOverlay1.opacity = 0
        }

        // Update second overlay
        if let rect = rect2 {
            let drawingRect = rect.offsetBy(dx: inset.left, dy: inset.top)
            let cornerRadius = 10.0
            paragraphOverlay2.path = UIBezierPath(roundedRect: drawingRect, cornerRadius: cornerRadius).cgPath

            let (fill, stroke) = colors(for: detent, default: .blue)
            paragraphOverlay2.fillColor = fill.cgColor
            paragraphOverlay2.strokeColor = stroke.cgColor
            paragraphOverlay2.opacity = 1
        } else {
            paragraphOverlay2.opacity = 0
        }

        // Update "Unrelated paragraphs" text
        if detent == AppSettings.unrelatedParagraphSpacing,
           let r1 = rect1,
           let r2 = rect2 {
            let topRect = r1.minY < r2.minY ? r1 : r2
            let bottomRect = r1.minY < r2.minY ? r2 : r1

            let gapCenterY = (topRect.maxY + bottomRect.minY) / 2.0 + inset.top

            let textSize = unrelatedTextLayer.preferredFrameSize()
            
            unrelatedTextLayer.frame = CGRect(
                x: (bounds.width - textSize.width) / 2.0,
                y: gapCenterY - (textSize.height / 2.0),
                width: textSize.width,
                height: textSize.height
            )
            unrelatedTextLayer.isHidden = false
            unrelatedTextLayer.opacity = 1
        } else {
            unrelatedTextLayer.opacity = 0
        }

        // Update "Related paragraphs" text
        if detent == AppSettings.relatedParagraphSpacing,
           let r1 = rect1,
           let r2 = rect2 {
            let topRect = r1.minY < r2.minY ? r1 : r2
            let bottomRect = r1.minY < r2.minY ? r2 : r1

            let gapCenterY = (topRect.maxY + bottomRect.minY) / 2.0 + inset.top

            let textSize = relatedTextLayer.preferredFrameSize()
            
            relatedTextLayer.frame = CGRect(
                x: (bounds.width - textSize.width) / 2.0,
                y: gapCenterY - (textSize.height / 2.0),
                width: textSize.width,
                height: textSize.height
            )
            relatedTextLayer.isHidden = false
            relatedTextLayer.opacity = 1
        } else {
            relatedTextLayer.opacity = 0
        }

        CATransaction.commit()
    }

    private func colors(for detent: CGFloat, default defaultColor: UIColor) -> (fill: UIColor, stroke: UIColor) {
        switch detent {
        case AppSettings.relatedParagraphSpacing:
            return (UIColor.green.withAlphaComponent(0.25), .green)
        case AppSettings.unrelatedParagraphSpacing:
            return (UIColor.yellow.withAlphaComponent(0.25), .yellow)
        default:
            return (defaultColor.withAlphaComponent(0.25), defaultColor)
        }
    }

    override func draw(_ rect: CGRect) {
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
