import UIKit

extension RichTextEditor.Coordinator {
    
    func printRawString(_ textView: UITextView) {
        print("---")
        textView.attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: textView.attributedText.length),
            options: []
        ) { attrs, range, _ in
            let substring = textView.attributedText.attributedSubstring(from: range).string
            print("\"\(substring)\" has attributes: \(attrs)")
        }
        print("---")
    }
}