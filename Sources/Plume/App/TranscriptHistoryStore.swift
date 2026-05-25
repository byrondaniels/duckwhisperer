import Foundation

struct TranscriptHistoryEntry: Codable {
    let id: UUID
    let createdAt: Date
    let text: String
    let appName: String
    let modelTitle: String
    let outputLanguageTitle: String
    let writingProfileTitle: String
}

enum TranscriptHistoryStore {
    private static let maxEntries = 50

    static func entries() -> [TranscriptHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: transcriptHistoryKey),
              let entries = try? JSONDecoder().decode([TranscriptHistoryEntry].self, from: data)
        else {
            return []
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    static func add(
        text: String,
        appName: String?,
        model: ModelChoice,
        outputLanguage: OutputLanguage,
        writingProfile: WritingProfile
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        var current = entries()
        current.insert(
            TranscriptHistoryEntry(
                id: UUID(),
                createdAt: Date(),
                text: trimmed,
                appName: appName ?? "Unknown App",
                modelTitle: model.title,
                outputLanguageTitle: outputLanguage.title,
                writingProfileTitle: writingProfile.title
            ),
            at: 0
        )
        current = Array(current.prefix(maxEntries))
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: transcriptHistoryKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: transcriptHistoryKey)
    }
}
