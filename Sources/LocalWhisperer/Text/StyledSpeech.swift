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

    private static let alienReplacements = [
        Replacement(source: "hello", target: "greetings"),
        Replacement(source: "hi", target: "greetings"),
        Replacement(source: "people", target: "earthlings"),
        Replacement(source: "person", target: "earthling"),
        Replacement(source: "team", target: "crew of this vessel"),
        Replacement(source: "meeting", target: "council transmission"),
        Replacement(source: "idea", target: "signal"),
        Replacement(source: "problem", target: "anomaly"),
        Replacement(source: "work", target: "mission"),
        Replacement(source: "today", target: "this solar cycle"),
        Replacement(source: "tomorrow", target: "the next solar cycle")
    ]

    private static let cowboyReplacements = [
        Replacement(source: "hello", target: "howdy"),
        Replacement(source: "hi", target: "howdy"),
        Replacement(source: "friend", target: "partner"),
        Replacement(source: "team", target: "posse"),
        Replacement(source: "meeting", target: "roundup"),
        Replacement(source: "problem", target: "trouble"),
        Replacement(source: "good", target: "mighty fine"),
        Replacement(source: "great", target: "mighty fine"),
        Replacement(source: "yes", target: "yep"),
        Replacement(source: "thanks", target: "much obliged")
    ]

    private static let pirateReplacements = [
        Replacement(source: "hello", target: "ahoy"),
        Replacement(source: "hi", target: "ahoy"),
        Replacement(source: "friend", target: "matey"),
        Replacement(source: "team", target: "crew"),
        Replacement(source: "boss", target: "captain"),
        Replacement(source: "meeting", target: "parley"),
        Replacement(source: "yes", target: "aye"),
        Replacement(source: "no", target: "nay"),
        Replacement(source: "money", target: "doubloons"),
        Replacement(source: "thanks", target: "fair winds")
    ]

    private static let robotReplacements = [
        Replacement(source: "hello", target: "greetings"),
        Replacement(source: "hi", target: "greetings"),
        Replacement(source: "yes", target: "affirmative"),
        Replacement(source: "no", target: "negative"),
        Replacement(source: "maybe", target: "probability uncertain"),
        Replacement(source: "good", target: "optimal"),
        Replacement(source: "bad", target: "suboptimal"),
        Replacement(source: "problem", target: "error condition"),
        Replacement(source: "think", target: "process"),
        Replacement(source: "thanks", target: "gratitude protocol complete")
    ]

    private static let shakespeareReplacements = [
        Replacement(source: "hello", target: "good morrow"),
        Replacement(source: "hi", target: "good morrow"),
        Replacement(source: "very", target: "most"),
        Replacement(source: "really", target: "verily"),
        Replacement(source: "before", target: "ere"),
        Replacement(source: "quickly", target: "with haste"),
        Replacement(source: "friend", target: "good companion"),
        Replacement(source: "problem", target: "vexing matter"),
        Replacement(source: "yes", target: "aye"),
        Replacement(source: "thanks", target: "many thanks")
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

    static func alien(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(alienReplacements, to: text)
        if sentenceCount(in: output) <= 2,
           !containsWholeWord("earthling", in: output),
           !containsWholeWord("transmission", in: output) {
            output = prefixFirstSentence("Greetings, earthling", in: output)
        }
        return appendBeforeFinalPunctuation("transmission complete", to: output)
    }

    static func cowboy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(cowboyReplacements, to: text)
        if sentenceCount(in: output) <= 2,
           !containsWholeWord("howdy", in: output) {
            output = prefixFirstSentence("Howdy", in: output)
        }
        if !containsWholeWord("partner", in: output) {
            output = appendBeforeFinalPunctuation("partner", to: output)
        }
        return output
    }

    static func pirate(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(pirateReplacements, to: text)
        if sentenceCount(in: output) <= 2,
           !containsWholeWord("ahoy", in: output) {
            output = prefixFirstSentence("Ahoy", in: output)
        }
        if !containsWholeWord("arr", in: output) {
            output = appendBeforeFinalPunctuation("arr", to: output)
        }
        return output
    }

    static func robot(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(robotReplacements, to: text)
        if !output.localizedCaseInsensitiveContains("beep boop") {
            output = "Beep boop. \(output)"
        }
        return appendBeforeFinalPunctuation("end of line", to: output)
    }

    static func shakespeare(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        var output = apply(shakespeareReplacements, to: text)
        if sentenceCount(in: output) <= 2,
           !containsWholeWord("verily", in: output) {
            output = prefixFirstSentence("Verily", in: output)
        }
        if !containsWholeWord("forsooth", in: output) {
            output = appendBeforeFinalPunctuation("forsooth", to: output)
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
