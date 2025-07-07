import UIKit

class RuledView: UIView {
    weak var textView: UITextView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.backgroundColor = .clear
        self.isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let textView = textView, let coordinator = textView.delegate as? RichTextEditor.Coordinator else { return }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white
        ]

        let inset = textView.textContainerInset

        // Draw the red border and index for the first pinched paragraph
        if let pinchedRect = coordinator.pinchedParagraphRect1, let index = coordinator.pinchedParagraphIndex1 {
            let drawingRect = pinchedRect.offsetBy(dx: inset.left, dy: inset.top)
            context.setStrokeColor(UIColor.red.cgColor)
            context.setFillColor(UIColor.red.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(2.0)
            context.fill(drawingRect)
            context.stroke(drawingRect.insetBy(dx: -2, dy: -2))

            let indexString = NSAttributedString(string: "\(index)", attributes: textAttributes)
            let indexSize = indexString.size()
            let indexPoint = CGPoint(x: drawingRect.midX - indexSize.width / 2, y: drawingRect.midY - indexSize.height / 2)
            indexString.draw(at: indexPoint)
        }

        // Draw the blue border and index for the second pinched paragraph
        if let pinchedRect = coordinator.pinchedParagraphRect2, let index = coordinator.pinchedParagraphIndex2 {
            let drawingRect = pinchedRect.offsetBy(dx: inset.left, dy: inset.top)
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setFillColor(UIColor.blue.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(2.0)
            context.fill(drawingRect)
            context.stroke(drawingRect.insetBy(dx: -2, dy: -2))

            let indexString = NSAttributedString(string: "\(index)", attributes: textAttributes)
            let indexSize = indexString.size()
            let indexPoint = CGPoint(x: drawingRect.midX - indexSize.width / 2, y: drawingRect.midY - indexSize.height / 2)
            indexString.draw(at: indexPoint)
        }

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

            // Adjust for paragraph spacing if this is the last line of a paragraph
            if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: characterRange.location, effectiveRange: nil) as? NSParagraphStyle {
                let paragraphRange = (textStorage.string as NSString).paragraphRange(for: characterRange)
                let isLastLineOfParagraph = NSMaxRange(characterRange) == NSMaxRange(paragraphRange)
                if isLastLineOfParagraph {
                    lineY -= paragraphStyle.paragraphSpacing
                }
            }

            // Draw the line from edge to edge of the view's bounds.
            context.move(to: CGPoint(x: self.bounds.minX, y: lineY))
            context.addLine(to: CGPoint(x: self.bounds.maxX, y: lineY))
            context.strokePath()

            glyphIndex = NSMaxRange(glyphRange)
        }
    }
}
