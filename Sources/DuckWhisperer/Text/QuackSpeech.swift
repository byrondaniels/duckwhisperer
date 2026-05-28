import Foundation

enum QuackSpeech {
    private struct Replacement {
        let source: String
        let target: String
    }

    private static let replacements = [
        Replacement(source: "as soon as possible", target: "as soon as the duck can paddle"),
        Replacement(source: "confusing problem", target: "ruffled feather"),
        Replacement(source: "for real", target: "for real, quack"),
        Replacement(source: "good morning", target: "good morning from the pond"),
        Replacement(source: "good night", target: "good night from the nest"),
        Replacement(source: "great job", target: "egg-cellent job"),
        Replacement(source: "i agree", target: "I agree, feathers and all"),
        Replacement(source: "i am not sure", target: "I'm not totally sure from this pond"),
        Replacement(source: "i don't know", target: "I don't know, quack"),
        Replacement(source: "i do not know", target: "I do not know, quack"),
        Replacement(source: "i think", target: "I think, with one careful flap"),
        Replacement(source: "let me know", target: "send a note to the nest"),
        Replacement(source: "no problem", target: "no ruffled feathers"),
        Replacement(source: "right now", target: "right now, quick paddle"),
        Replacement(source: "sounds good", target: "sounds egg-cellent"),
        Replacement(source: "thank you", target: "thank you, quack"),
        Replacement(source: "thanks a lot", target: "thanks a lot, quack"),
        Replacement(source: "update the team", target: "update the flock"),
        Replacement(source: "update my team", target: "update my flock"),
        Replacement(source: "update our team", target: "update our flock"),
        Replacement(source: "is not working", target: "is not paddling right"),
        Replacement(source: "not working", target: "not paddling right"),
        Replacement(source: "that is bad", target: "that has ruffled feathers"),
        Replacement(source: "that is confusing", target: "that has the pond rippling"),
        Replacement(source: "that is good", target: "that is egg-cellent"),
        Replacement(source: "that is great", target: "that is egg-cellent"),
        Replacement(source: "that is perfect", target: "that is egg-cellent"),
        Replacement(source: "that is weird", target: "that is a bit ruffled"),
        Replacement(source: "that's bad", target: "that's ruffled"),
        Replacement(source: "that's confusing", target: "that's making pond ripples"),
        Replacement(source: "that's good", target: "that's egg-cellent"),
        Replacement(source: "that's great", target: "that's egg-cellent"),
        Replacement(source: "that's perfect", target: "that's egg-cellent"),
        Replacement(source: "that's weird", target: "that's a bit ruffled"),
        Replacement(source: "this is bad", target: "this is ruffled"),
        Replacement(source: "this is confusing", target: "this is making pond ripples"),
        Replacement(source: "this is good", target: "this is egg-cellent"),
        Replacement(source: "this is great", target: "this is egg-cellent"),
        Replacement(source: "this is perfect", target: "this is egg-cellent"),
        Replacement(source: "this is weird", target: "this is a bit ruffled"),
        Replacement(source: "what is going on", target: "what is happening on the pond"),
        Replacement(source: "what's going on", target: "what is happening on the pond"),
        Replacement(source: "you are right", target: "you are right on the beak"),
        Replacement(source: "you're right", target: "you're right on the beak"),
        Replacement(source: "answer", target: "duck answer"),
        Replacement(source: "app", target: "pond tool"),
        Replacement(source: "bad", target: "ruffled"),
        Replacement(source: "bug", target: "pond bug"),
        Replacement(source: "buggy", target: "ruffled"),
        Replacement(source: "busy", target: "flapping"),
        Replacement(source: "call", target: "quack call"),
        Replacement(source: "change", target: "feather tweak"),
        Replacement(source: "check", target: "beak check"),
        Replacement(source: "clear", target: "smooth as pond water"),
        Replacement(source: "client", target: "pond friend"),
        Replacement(source: "company", target: "flock"),
        Replacement(source: "confusing", target: "ruffling"),
        Replacement(source: "cool", target: "duck-cool"),
        Replacement(source: "create", target: "hatch"),
        Replacement(source: "deadline", target: "nest deadline"),
        Replacement(source: "delete", target: "pluck out"),
        Replacement(source: "document", target: "pond note"),
        Replacement(source: "done", target: "landed"),
        Replacement(source: "email", target: "nest mail"),
        Replacement(source: "excellent", target: "egg-cellent"),
        Replacement(source: "fast", target: "quick-flap"),
        Replacement(source: "feature", target: "feather"),
        Replacement(source: "finish", target: "land"),
        Replacement(source: "friend", target: "pond friend"),
        Replacement(source: "good", target: "egg-cellent"),
        Replacement(source: "great", target: "egg-cellent"),
        Replacement(source: "hard", target: "ruffled"),
        Replacement(source: "hello", target: "hello, quack"),
        Replacement(source: "hi", target: "hi, quack"),
        Replacement(source: "idea", target: "nest idea"),
        Replacement(source: "important", target: "big pond"),
        Replacement(source: "issue", target: "ruffled feather"),
        Replacement(source: "manager", target: "lead duck"),
        Replacement(source: "meeting", target: "pond huddle"),
        Replacement(source: "message", target: "nest note"),
        Replacement(source: "mistake", target: "ruffled feather"),
        Replacement(source: "nice", target: "egg-cellent"),
        Replacement(source: "office", target: "nest"),
        Replacement(source: "perfect", target: "egg-cellent"),
        Replacement(source: "person", target: "pond pal"),
        Replacement(source: "people", target: "flock"),
        Replacement(source: "plan", target: "flight plan"),
        Replacement(source: "problem", target: "ruffled feather"),
        Replacement(source: "project", target: "pond project"),
        Replacement(source: "quickly", target: "with a quick flap"),
        Replacement(source: "review", target: "beak check"),
        Replacement(source: "schedule", target: "flight plan"),
        Replacement(source: "slow", target: "slow paddle"),
        Replacement(source: "start", target: "take off"),
        Replacement(source: "strange", target: "ruffled"),
        Replacement(source: "task", target: "nest task"),
        Replacement(source: "team", target: "flock"),
        Replacement(source: "thanks", target: "thanks, quack"),
        Replacement(source: "update", target: "fresh pond note"),
        Replacement(source: "weird", target: "ruffled"),
        Replacement(source: "work", target: "paddle-work"),
        Replacement(source: "working", target: "paddling"),
        Replacement(source: "yes", target: "yes, quack")
    ]

    static func render(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard containsAlphanumeric(in: trimmed) else {
            return "."
        }

        return apply(replacements, to: text)
    }

    private static func apply(_ replacements: [Replacement], to text: String) -> String {
        let sortedReplacements = replacements.sorted {
            if $0.source.count == $1.source.count {
                return $0.source < $1.source
            }
            return $0.source.count > $1.source.count
        }
        let replacementBySource = Dictionary(
            uniqueKeysWithValues: sortedReplacements.map { replacement in
                (replacement.source.lowercased(), replacement.target)
            }
        )
        let escapedSources = sortedReplacements
            .map { NSRegularExpression.escapedPattern(for: $0.source) }
            .joined(separator: "|")
        let pattern = #"(?i)(?<![A-Za-z0-9])(?:\#(escapedSources))(?![A-Za-z0-9])"#
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
            guard let replacement = replacementBySource[matched.lowercased()] else {
                continue
            }
            output.replaceSubrange(range, with: casedReplacement(replacement, matching: matched))
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

    private static func containsAlphanumeric(in text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}
