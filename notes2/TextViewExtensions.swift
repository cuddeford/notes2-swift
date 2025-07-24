import UIKit

class CustomTextView: UITextView {
    weak var coordinator: RichTextEditor.Coordinator?

    override func caretRect(for position: UITextPosition) -> CGRect {
        var originalRect = super.caretRect(for: position)

        let offset = self.offset(from: beginningOfDocument, to: position)
        if offset < attributedText.length {
            let paragraphStyle = attributedText.attribute(.paragraphStyle, at: offset, effectiveRange: nil) as? NSParagraphStyle
            let paragraphSpacing = paragraphStyle?.paragraphSpacing ?? 0.0

            if originalRect.height - paragraphSpacing > 0 && originalRect.height - paragraphSpacing > paragraphStyle?.minimumLineHeight ?? paragraphSpacing {
                originalRect.size.height -= paragraphSpacing
            }
        }

        return originalRect
    }

    override func paste(_ sender: Any?) {
        if let pastedText = UIPasteboard.general.string {
            let attributes = self.typingAttributes
            let attributedString = NSAttributedString(string: pastedText, attributes: attributes)
            self.textStorage.replaceCharacters(in: self.selectedRange, with: attributedString)
            self.delegate?.textViewDidChange?(self)
        } else {
            super.paste(sender)
        }
    }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        let originalRects = super.selectionRects(for: range)
        var adjustedRects: [UITextSelectionRect] = []

        for selectionRect in originalRects {
            adjustedRects.append(CustomTextSelectionRect(
                rect: CGRect(
                    x: selectionRect.rect.minX,
                    y: selectionRect.rect.minY,
                    width: selectionRect.rect.width,
                    height: originalRects[0].rect.height,
                ),
                writingDirection: selectionRect.writingDirection,
                containsStart: selectionRect.containsStart,
                containsEnd: selectionRect.containsEnd,
                isVertical: selectionRect.isVertical
            ))
        }

        return adjustedRects
    }
}

class CustomTextSelectionRect: UITextSelectionRect {
    private let _rect: CGRect
    private let _writingDirection: NSWritingDirection
    private let _containsStart: Bool
    private let _containsEnd: Bool
    private let _isVertical: Bool

    init(rect: CGRect, writingDirection: NSWritingDirection, containsStart: Bool, containsEnd: Bool, isVertical: Bool) {
        _rect = rect
        _writingDirection = writingDirection
        _containsStart = containsStart
        _containsEnd = containsEnd
        _isVertical = isVertical
    }

    override var rect: CGRect { return _rect }
    override var writingDirection: NSWritingDirection { return _writingDirection }
    override var containsStart: Bool { return _containsStart }
    override var containsEnd: Bool { return _containsEnd }
    override var isVertical: Bool { return _isVertical }
}