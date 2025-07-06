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

        let lineColor = UIColor.lightGray.withAlphaComponent(0.7)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1.0) // As you requested

        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        var glyphIndex = 0

        while glyphIndex < layoutManager.numberOfGlyphs {
            var glyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &glyphRange)
            let lineY = lineRect.origin.y + lineRect.height

            // Draw the line from edge to edge of the view's bounds.
            context.move(to: CGPoint(x: self.bounds.minX, y: lineY))
            context.addLine(to: CGPoint(x: self.bounds.maxX, y: lineY))
            context.strokePath()

            glyphIndex = NSMaxRange(glyphRange)
        }
    }
}
