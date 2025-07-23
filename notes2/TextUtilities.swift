import UIKit

func paragraphRange(for text: NSAttributedString, at location: Int) -> NSRange {
    let string = text.string as NSString
    let length = string.length
    if length == 0 {
        return NSRange(location: 0, length: 0)
    }
    let safeLocation = min(max(location, 0), length)
    return string.paragraphRange(for: NSRange(location: safeLocation, length: 0))
}

func wordRange(for text: NSAttributedString, at location: Int) -> NSRange {
    let string = text.string as NSString
    let length = string.length
    guard length > 0 else { return NSRange(location: 0, length: 0) }
    let safeLocation = min(max(location, 0), length - 1)
    let range = string.rangeOfWord(at: safeLocation)
    return range
}

extension NSString {
    func rangeOfWord(at location: Int) -> NSRange {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let length = self.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        var start = location
        var end = location

        // Move start to the beginning of the word
        while start > 0 && !separators.contains(UnicodeScalar(character(at: start - 1))!) {
            start -= 1
        }
        // Move end to the end of the word
        while end < length && !separators.contains(UnicodeScalar(character(at: end))!) {
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}