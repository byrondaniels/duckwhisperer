import Foundation

enum QuackSpeech {
    private static let quacks = [
        "quack",
        "quaack",
        "quaaack",
        "quaaaack",
        "quaaaaack",
        "quaaaaaack",
        "quackk",
        "quackkk",
        "quuack",
        "quuuack",
        "QUACK",
        "QUAACK",
        "QUAAACK",
        "QUAAAACK",
        "quack-quack",
        "quack quack",
        "quaack-quack",
        "quaaack quack",
        "quaaaack quack",
        "quack-quaaack",
        "QUACK-QUACK"
    ]

    static func render(_ text: String) -> String {
        let sentenceParts = splitIntoSentences(text)
        guard !sentenceParts.isEmpty else {
            return "Quack quack."
        }

        let rendered = sentenceParts.compactMap { part -> String? in
            let words = words(in: part.body)
            guard !words.isEmpty else {
                return nil
            }

            let quacks = words.enumerated().map { index, word in
                quack(for: word, at: index)
            }
            return sentenceCase(quacks.joined(separator: " ")) + part.terminator
        }

        return rendered.isEmpty ? "Quack quack." : rendered.joined(separator: " ")
    }

    private static func splitIntoSentences(_ text: String) -> [(body: String, terminator: String)] {
        var result: [(body: String, terminator: String)] = []
        var current = ""

        for character in text {
            if ".!?".contains(character) {
                let body = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    result.append((body: body, terminator: String(character)))
                }
                current.removeAll(keepingCapacity: true)
            } else if character.isNewline {
                let body = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    result.append((body: body, terminator: "."))
                }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(character)
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append((body: tail, terminator: "."))
        }

        return result
    }

    private static func words(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func quack(for word: String, at index: Int) -> String {
        let value = word.unicodeScalars.reduce(index * 17) { partial, scalar in
            partial + Int(scalar.value)
        }
        return quacks[value % quacks.count]
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).uppercased() + String(text.dropFirst())
    }
}
