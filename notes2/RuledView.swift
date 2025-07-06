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
        guard let context = UIGraphicsGetCurrentContext(), let textView = textView else { return }

        let lineColor = UIColor.lightGray.withAlphaComponent(1.0)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1.0) // As you requested

        let layoutManager = textView.layoutManager
        let textStorage = textView.textStorage
        let textContainer = textView.textContainer

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
