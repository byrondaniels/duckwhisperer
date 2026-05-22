import Foundation

struct CommandPhraseResult {
    let text: String
    let outputLanguage: OutputLanguage
    let writingProfile: WritingProfile
    let commandName: String?
}

enum CommandPhraseProcessor {
    static func process(
        _ text: String,
        outputLanguage: OutputLanguage,
        writingProfile: WritingProfile
    ) -> CommandPhraseResult {
        let normalized = WritingProfileRenderer.normalizeBlankAudio(text)
        guard normalized != "." else {
            return CommandPhraseResult(
                text: normalized,
                outputLanguage: outputLanguage,
                writingProfile: writingProfile,
                commandName: nil
            )
        }

        if let body = stripPrefix(["make that shorter", "make this shorter", "shorten this"], from: normalized) {
            return CommandPhraseResult(
                text: WritingProfileRenderer.shortened(body),
                outputLanguage: outputLanguage,
                writingProfile: WritingProfile.choice(for: "smart"),
                commandName: "Shorten"
            )
        }

        if let body = stripPrefix(["turn this into bullets", "make this bullets", "bullet point this"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: outputLanguage,
                writingProfile: WritingProfile.choice(for: "bullet-notes"),
                commandName: "Bullets"
            )
        }

        if let body = stripPrefix(["rewrite professionally", "make this professional", "clean this up"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: outputLanguage,
                writingProfile: WritingProfile.choice(for: "clean-email"),
                commandName: "Professional"
            )
        }

        if let body = stripPrefix(["meeting notes", "turn this into meeting notes"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: outputLanguage,
                writingProfile: WritingProfile.choice(for: "meeting-notes"),
                commandName: "Meeting Notes"
            )
        }

        if let body = stripPrefix(["code prompt", "make this a code prompt"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: outputLanguage,
                writingProfile: WritingProfile.choice(for: "code-prompt"),
                commandName: "Code Prompt"
            )
        }

        if let body = stripPrefix(["translate to dutch", "output in dutch"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: OutputLanguage.choice(for: "nl"),
                writingProfile: writingProfile,
                commandName: "Dutch"
            )
        }

        if let body = stripPrefix(["translate to french", "output in french"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: OutputLanguage.choice(for: "fr"),
                writingProfile: writingProfile,
                commandName: "French"
            )
        }

        if let body = stripPrefix(["duck mode", "make this duck"], from: normalized) {
            return CommandPhraseResult(
                text: body,
                outputLanguage: OutputLanguage.choice(for: "duck"),
                writingProfile: writingProfile,
                commandName: "Duck"
            )
        }

        return CommandPhraseResult(
            text: normalized,
            outputLanguage: outputLanguage,
            writingProfile: writingProfile,
            commandName: nil
        )
    }

    private static func stripPrefix(_ prefixes: [String], from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.localizedLowercase
        for prefix in prefixes {
            let normalizedPrefix = prefix.localizedLowercase
            if lowercased == normalizedPrefix {
                return "."
            }
            if lowercased.hasPrefix(normalizedPrefix + " ") {
                let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
                return trimmed[start...]
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":-,")))
            }
        }
        return nil
    }
}
