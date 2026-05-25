import Foundation

struct PersonalDictionaryEntry {
    let spoken: String
    let replacement: String
}

enum PersonalDictionary {
    static func entries(from rawText: String) -> [PersonalDictionaryEntry] {
        rawText
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                    return nil
                }

                let parts: [String]
                if trimmed.contains("=") {
                    parts = trimmed.components(separatedBy: "=")
                } else if trimmed.contains("->") {
                    parts = trimmed.components(separatedBy: "->")
                } else {
                    return nil
                }

                guard parts.count >= 2 else {
                    return nil
                }

                let spoken = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let replacement = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !spoken.isEmpty, !replacement.isEmpty else {
                    return nil
                }
                return PersonalDictionaryEntry(spoken: spoken, replacement: replacement)
            }
    }

    static func apply(_ entries: [PersonalDictionaryEntry], to text: String) -> String {
        entries.reduce(text) { partial, entry in
            replace(entry.spoken, with: entry.replacement, in: partial)
        }
    }

    private static func replace(_ source: String, with replacement: String, in text: String) -> String {
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
            output.replaceSubrange(range, with: casedReplacement(replacement, matching: matched))
        }
        return output
    }

    private static func casedReplacement(_ replacement: String, matching matched: String) -> String {
        if matched == matched.uppercased() {
            return replacement.uppercased()
        }
        if let first = matched.first, first.isUppercase {
            return String(replacement.prefix(1)).uppercased() + replacement.dropFirst()
        }
        return replacement
    }
}
