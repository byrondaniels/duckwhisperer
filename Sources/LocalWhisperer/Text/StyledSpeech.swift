import Foundation

enum StyledSpeech {
    private struct Replacement {
        let source: String
        let target: String
    }

    private static let britishReplacements = [
        Replacement(source: "awesome", target: "brilliant"),
        Replacement(source: "bathroom", target: "loo"),
        Replacement(source: "candy", target: "sweets"),
        Replacement(source: "cell phone", target: "mobile"),
        Replacement(source: "color", target: "colour"),
        Replacement(source: "favorite", target: "favourite"),
        Replacement(source: "fries", target: "chips"),
        Replacement(source: "garbage", target: "rubbish"),
        Replacement(source: "gas", target: "petrol"),
        Replacement(source: "gotten", target: "got"),
        Replacement(source: "line", target: "queue"),
        Replacement(source: "movie", target: "film"),
        Replacement(source: "pants", target: "trousers"),
        Replacement(source: "parking lot", target: "car park"),
        Replacement(source: "sidewalk", target: "pavement"),
        Replacement(source: "soccer", target: "football"),
        Replacement(source: "sweater", target: "jumper"),
        Replacement(source: "trash", target: "rubbish"),
        Replacement(source: "truck", target: "lorry"),
        Replacement(source: "vacation", target: "holiday"),
        Replacement(source: "yeah", target: "yes"),
        Replacement(source: "yep", target: "yes")
    ]

    private static let genZReplacements = [
        Replacement(source: "awesome", target: "fire"),
        Replacement(source: "bad", target: "not it"),
        Replacement(source: "cool", target: "based"),
        Replacement(source: "definitely", target: "for sure"),
        Replacement(source: "excellent", target: "iconic"),
        Replacement(source: "good", target: "solid"),
        Replacement(source: "great", target: "fire"),
        Replacement(source: "honestly", target: "ngl"),
        Replacement(source: "really", target: "lowkey"),
        Replacement(source: "seriously", target: "fr"),
        Replacement(source: "very", target: "super"),
        Replacement(source: "yes", target: "yeah"),
        Replacement(source: "yeah", target: "yeah")
    ]

    static func british(_ text: String) -> String {
        guard containsAlphanumeric(in: text) else {
            return text
        }

        var output = apply(britishReplacements, to: text)
        if sentenceCount(in: output) == 1,
           !containsCasualBritishCue(output),
           !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = appendBeforeFinalPunctuation("mate", to: output)
        }
        return output
    }

    static func genZ(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(genZReplacements, to: text)
        if sentenceCount(in: output) <= 2 {
            output = prefixFirstSentence("Lowkey", in: output)
        }
        if !containsWholeWord("fr", in: output),
           !containsWholeWord("ngl", in: output),
           !containsWholeWord("lowkey", in: output) {
            output = appendBeforeFinalPunctuation("fr", to: output)
        }
        return output
    }

    private static func apply(_ replacements: [Replacement], to text: String) -> String {
        replacements.reduce(text) { partial, replacement in
            replacePhrase(replacement.source, with: replacement.target, in: partial)
        }
    }

    private static func replacePhrase(_ source: String, with target: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: source)
        let pattern = #"(?i)(?<![A-Za-z0-9])"# + escaped + #"(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var output = text
        let matches = regex.matches(
            in: output,
            range: NSRange(output.startIndex..<output.endIndex, in: output)
        )

        for match in matches.reversed() {
            guard let range = Range(match.range, in: output) else {
                continue
            }
            let matched = String(output[range])
            output.replaceSubrange(range, with: casedReplacement(target, matching: matched))
        }

        return output
    }

    private static func casedReplacement(_ replacement: String, matching matched: String) -> String {
        if matched == matched.uppercased() {
            return replacement.uppercased()
        }

        if let first = matched.first, first.isUppercase {
            return sentenceCase(replacement)
        }

        return replacement
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).uppercased() + String(text.dropFirst())
    }

    private static func sentenceCount(in text: String) -> Int {
        let count = text.filter { ".!?".contains($0) }.count
        return max(1, count)
    }

    private static func containsCasualBritishCue(_ text: String) -> Bool {
        ["mate", "brilliant", "queue", "rubbish", "loo"].contains { cue in
            containsWholeWord(cue, in: text)
        }
    }

    private static func containsWholeWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = #"(?i)(?<![A-Za-z0-9])"# + escaped + #"(?![A-Za-z0-9])"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func containsAlphanumeric(in text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private static func prefixFirstSentence(_ prefix: String, in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.localizedCaseInsensitiveContains(prefix)
        else {
            return text
        }

        return "\(prefix), \(lowercaseFirst(trimmed))"
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).lowercased() + String(text.dropFirst())
    }

    private static func appendBeforeFinalPunctuation(_ phrase: String, to text: String) -> String {
        guard let last = text.last,
              ".!?".contains(last)
        else {
            return "\(text) \(phrase)."
        }

        let body = text.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(body), \(phrase)\(last)"
    }
}
