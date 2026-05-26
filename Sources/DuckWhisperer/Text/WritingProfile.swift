import Foundation

struct WritingProfile: Equatable {
    let id: String
    let title: String
    let detail: String

    static let all: [WritingProfile] = [
        WritingProfile(id: "smart", title: "Smart Clean", detail: "default polished dictation"),
        WritingProfile(id: "clean-email", title: "Clean Email", detail: "clear paragraphs for email"),
        WritingProfile(id: "slack-casual", title: "Slack / Teams", detail: "short, casual workplace tone"),
        WritingProfile(id: "meeting-notes", title: "Meeting Notes", detail: "scannable meeting bullets"),
        WritingProfile(id: "bullet-notes", title: "Bullet Points", detail: "simple bullet list"),
        WritingProfile(id: "raw", title: "Raw Dictation", detail: "minimal cleanup"),
        WritingProfile(id: "code-prompt", title: "AI Prompt", detail: "clear prompt for ChatGPT or Claude")
    ]

    static var defaultChoice: WritingProfile {
        all[0]
    }

    static func choice(for id: String?) -> WritingProfile {
        all.first { $0.id == id } ?? defaultChoice
    }
}

enum WritingProfileRenderer {
    static func render(_ text: String, profile: WritingProfile) -> String {
        let normalized = normalizeWhitespace(text)
        guard containsAlphanumeric(normalized) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "." : text
        }

        switch profile.id {
        case "raw":
            return text
        case "clean-email":
            return sentenceParagraphs(normalized)
        case "slack-casual":
            return slackStyle(normalized)
        case "meeting-notes":
            return bulletize(normalized, heading: "Notes")
        case "code-prompt":
            return codePrompt(normalized)
        case "bullet-notes":
            return bulletize(normalized, heading: nil)
        default:
            return sentenceParagraphs(normalized)
        }
    }

    static func normalizeBlankAudio(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.localizedCaseInsensitiveCompare("[blank_audio]") == .orderedSame {
            return "."
        }
        return text
    }

    static func bulletize(_ text: String, heading: String?) -> String {
        let parts = sentenceParts(text)
        let bullets = parts.isEmpty ? [normalizeWhitespace(text)] : parts
        let body = bullets
            .map { "- \($0)" }
            .joined(separator: "\n")
        guard let heading else {
            return body
        }
        return "\(heading):\n\(body)"
    }

    static func shortened(_ text: String) -> String {
        let parts = sentenceParts(text)
        guard let first = parts.first else {
            return text
        }
        if first.count <= 220 {
            return first
        }
        return String(first.prefix(217)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func sentenceParagraphs(_ text: String) -> String {
        let parts = sentenceParts(text)
        guard !parts.isEmpty else {
            return ensureFinalPeriod(text)
        }

        if parts.count <= 2 {
            return parts.map(ensureFinalPeriod).joined(separator: " ")
        }

        var paragraphs: [String] = []
        var index = 0
        while index < parts.count {
            let end = min(index + 2, parts.count)
            paragraphs.append(parts[index..<end].map(ensureFinalPeriod).joined(separator: " "))
            index = end
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func slackStyle(_ text: String) -> String {
        var output = text
            .replacingOccurrences(of: "I would like to", with: "I want to", options: .caseInsensitive)
            .replacingOccurrences(of: "please ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "thank you", with: "thanks", options: .caseInsensitive)
        output = sentenceParagraphs(output)
        return output
    }

    private static func codePrompt(_ text: String) -> String {
        let trimmed = ensureFinalPeriod(text)
        if trimmed.localizedCaseInsensitiveContains("please") ||
            trimmed.localizedCaseInsensitiveContains("compare") ||
            trimmed.localizedCaseInsensitiveContains("summarize") ||
            trimmed.localizedCaseInsensitiveContains("recommend") {
            return trimmed
        }
        return "Please help with this: \(lowercaseFirst(trimmed))"
    }

    private static func sentenceParts(_ text: String) -> [String] {
        let pattern = #"[^.!?\n]+[.!?]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else {
                return nil
            }
            let part = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            return part.isEmpty ? nil : String(part)
        }
    }

    private static func ensureFinalPeriod(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else {
            return trimmed
        }
        return "\(trimmed)."
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).lowercased() + String(text.dropFirst())
    }

    private static func containsAlphanumeric(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}
