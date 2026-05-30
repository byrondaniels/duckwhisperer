import Foundation

enum SpokenFormattingProcessor {
    private static let quotePairPattern = #"(?i)\bquote\b[\s,;:.-]+(.+?)\s+\bend\s+quote\b"#

    static func apply(_ text: String) -> String {
        applyQuotePairs(text)
    }

    private static func applyQuotePairs(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: quotePairPattern) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else {
            return text
        }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else {
                continue
            }
            let quotedRange = match.range(at: 1)
            guard quotedRange.location != NSNotFound else {
                continue
            }
            let quotedText = cleanQuotedText(nsText.substring(with: quotedRange))
            guard quotedText.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else {
                continue
            }
            mutable.replaceCharacters(in: match.range, with: "\"\(quotedText)\"")
        }

        return String(mutable)
    }

    private static func cleanQuotedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",;:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
