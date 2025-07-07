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

        // Draw the red border and index for the first pinched paragraph
        if let pinchedRect = coordinator.pinchedParagraphRect1, let index = coordinator.pinchedParagraphIndex1 {
            context.setStrokeColor(UIColor.red.cgColor)
            context.setFillColor(UIColor.red.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(2.0)
            context.fill(pinchedRect)
            context.stroke(pinchedRect.insetBy(dx: -2, dy: -2))
            
            let indexString = NSAttributedString(string: "\(index)", attributes: textAttributes)
            let indexSize = indexString.size()
            let indexPoint = CGPoint(x: pinchedRect.midX - indexSize.width / 2, y: pinchedRect.midY - indexSize.height / 2)
            indexString.draw(at: indexPoint)
        }

        // Draw the blue border and index for the second pinched paragraph
        if let pinchedRect = coordinator.pinchedParagraphRect2, let index = coordinator.pinchedParagraphIndex2 {
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setFillColor(UIColor.blue.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(2.0)
            context.fill(pinchedRect)
            context.stroke(pinchedRect.insetBy(dx: -2, dy: -2))

            let indexString = NSAttributedString(string: "\(index)", attributes: textAttributes)
            let indexSize = indexString.size()
            let indexPoint = CGPoint(x: pinchedRect.midX - indexSize.width / 2, y: pinchedRect.midY - indexSize.height / 2)
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

            var lineY = lineRect.origin.y + lineRect.height

            // Adjust for paragraph spacing if this is the last line of a paragraph
            if let paragraphStyle = textStorage.attribute(.paragraphStyle, at: characterRange.location, effectiveRange: nil) as? NSParagraphStyle {
                let paragraphRange = (textStorage.string as NSString).paragraphRange(for: characterRange)
                let isLastLineOfParagraph = NSMaxRange(characterRange) == NSMaxRange(paragraphRange)
                if isLastLineOfParagraph {
                    lineY -= paragraphStyle.paragraphSpacing
                }
            }

            // Adjust for the "lines too high" issue.
            // This offset moves the line down slightly to be truly "underneath" the text.
            // The exact value might need to be fine-tuned.
            let verticalOffset: CGFloat = 15.0

            lineY += verticalOffset

            // Draw the line from edge to edge of the view's bounds.
            context.move(to: CGPoint(x: self.bounds.minX, y: lineY))
            context.addLine(to: CGPoint(x: self.bounds.maxX, y: lineY))
            context.strokePath()

            glyphIndex = NSMaxRange(glyphRange)
        }
    }
}
