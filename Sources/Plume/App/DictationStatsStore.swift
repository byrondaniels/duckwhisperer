import Foundation

struct DictationStats: Codable {
    var completedDictations: Int
    var wordsDictated: Int
    var spokenSeconds: TimeInterval
    var estimatedTypingSeconds: TimeInterval
    var savedSeconds: TimeInterval
    var updatedAt: Date?

    static let empty = DictationStats(
        completedDictations: 0,
        wordsDictated: 0,
        spokenSeconds: 0,
        estimatedTypingSeconds: 0,
        savedSeconds: 0,
        updatedAt: nil
    )

    var savedTimeText: String {
        Self.formatDuration(savedSeconds)
    }

    var menuSummary: String {
        if completedDictations == 0 {
            return "Time Saved: 0s typing"
        }
        return "Time Saved: \(savedTimeText) typing"
    }

    var detailSummary: String {
        if completedDictations == 0 {
            return "No completed dictations yet."
        }
        let dictationLabel = completedDictations == 1 ? "dictation" : "dictations"
        let wordLabel = wordsDictated == 1 ? "word" : "words"
        return "\(savedTimeText) saved - \(wordsDictated) \(wordLabel) - \(completedDictations) \(dictationLabel)"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(remainingSeconds)s"
    }
}

enum DictationStatsStore {
    private static let typingWordsPerMinute = 40.0

    static func current() -> DictationStats {
        guard let data = UserDefaults.standard.data(forKey: dictationStatsKey),
              let stats = try? JSONDecoder().decode(DictationStats.self, from: data)
        else {
            return .empty
        }
        return stats
    }

    static func record(text: String, spokenDuration: TimeInterval) {
        let words = wordCount(in: text)
        guard words > 0 else {
            return
        }

        let estimatedTypingSeconds = Double(words) / typingWordsPerMinute * 60
        let savedSeconds = max(0, estimatedTypingSeconds - max(0, spokenDuration))

        var stats = current()
        stats.completedDictations += 1
        stats.wordsDictated += words
        stats.spokenSeconds += max(0, spokenDuration)
        stats.estimatedTypingSeconds += estimatedTypingSeconds
        stats.savedSeconds += savedSeconds
        stats.updatedAt = Date()
        save(stats)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: dictationStatsKey)
    }

    private static func save(_ stats: DictationStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: dictationStatsKey)
        }
    }

    private static func wordCount(in text: String) -> Int {
        let pattern = #"[\p{L}\p{N}]+(?:'[\p{L}\p{N}]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.numberOfMatches(in: text, range: range)
    }
}
