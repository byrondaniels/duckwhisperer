import CryptoKit
import Foundation

struct ModelAsset: Equatable {
    let filename: String
    let diskSizeText: String
    let downloadSizeText: String
    let expectedSHA1: String
}

struct ModelChoice: Equatable {
    let id: String
    let title: String
    let detail: String
    let benchmarkSummary: String
    let accuracyRating: Int
    let speedRating: Int
    let memoryRating: Int
    let englishAsset: ModelAsset
    let multilingualAsset: ModelAsset
    let bundledByDefault: Bool

    var relativePath: String {
        "Models/\(englishAsset.filename)"
    }

    var downloadURL: URL {
        downloadURL(for: .defaultChoice)
    }

    var filename: String {
        englishAsset.filename
    }

    var diskSizeText: String {
        englishAsset.diskSizeText
    }

    var downloadSizeText: String {
        englishAsset.downloadSizeText
    }

    var expectedSHA1: String {
        englishAsset.expectedSHA1
    }

    func asset(for inputLanguage: InputLanguageChoice) -> ModelAsset {
        inputLanguage.isEnglish ? englishAsset : multilingualAsset
    }

    func filename(for inputLanguage: InputLanguageChoice) -> String {
        asset(for: inputLanguage).filename
    }

    func diskSizeText(for inputLanguage: InputLanguageChoice) -> String {
        asset(for: inputLanguage).diskSizeText
    }

    func downloadSizeText(for inputLanguage: InputLanguageChoice) -> String {
        asset(for: inputLanguage).downloadSizeText
    }

    func expectedSHA1(for inputLanguage: InputLanguageChoice) -> String {
        asset(for: inputLanguage).expectedSHA1
    }

    func downloadURL(for inputLanguage: InputLanguageChoice) -> URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename(for: inputLanguage))")!
    }

    func languageScopeText(for inputLanguage: InputLanguageChoice) -> String {
        inputLanguage.isEnglish ? "English speech" : "More languages"
    }

    var friendlyTitle: String {
        switch id {
        case "small-en":
            return "Best Accuracy"
        case "base-en":
            return "Fast"
        case "tiny-en":
            return "Fastest"
        default:
            return title
        }
    }

    var friendlyDetail: String {
        switch id {
        case "small-en":
            return "recommended for everyday dictation"
        case "base-en":
            return "quicker, still solid"
        case "tiny-en":
            return "quick tests and short notes"
        default:
            return detail
        }
    }

    var friendlyMenuTitle: String {
        switch id {
        case "small-en":
            return "Best Accuracy - Recommended"
        case "base-en":
            return "Fast - Smaller Download"
        case "tiny-en":
            return "Fastest - Rough Drafts"
        default:
            return title
        }
    }

    static let all: [ModelChoice] = [
        ModelChoice(
            id: "small-en",
            title: "Small English - Recommended",
            detail: "best default for English dictation",
            benchmarkSummary: "Accuracy 5/5, speed 3/5, memory 3/5. 98.3% on the dictation benchmark; 1.95s median for 47.5s audio; about 713 MB peak RAM.",
            accuracyRating: 5,
            speedRating: 3,
            memoryRating: 3,
            englishAsset: ModelAsset(
                filename: "ggml-small.en.bin",
                diskSizeText: "487.6 MB",
                downloadSizeText: "487.6 MB",
                expectedSHA1: "db8a495a91d927739e50b3fc1cc4c6b8f6c2d022"
            ),
            multilingualAsset: ModelAsset(
                filename: "ggml-small.bin",
                diskSizeText: "488.0 MB",
                downloadSizeText: "488.0 MB",
                expectedSHA1: "55356645c2b361a969dfd0ef2c5a50d530afd8d5"
            ),
            bundledByDefault: false
        ),
        ModelChoice(
            id: "base-en",
            title: "Base English",
            detail: "fast English dictation",
            benchmarkSummary: "Accuracy 4/5, speed 4/5, memory 4/5. 97.5% on the dictation benchmark; 1.04s median; about 311 MB peak RAM.",
            accuracyRating: 4,
            speedRating: 4,
            memoryRating: 4,
            englishAsset: ModelAsset(
                filename: "ggml-base.en.bin",
                diskSizeText: "148.0 MB",
                downloadSizeText: "148.0 MB",
                expectedSHA1: "137c40403d78fd54d454da0f9bd998f78703390c"
            ),
            multilingualAsset: ModelAsset(
                filename: "ggml-base.bin",
                diskSizeText: "148.0 MB",
                downloadSizeText: "148.0 MB",
                expectedSHA1: "465707469ff3a37a2b9b8d8f89f2f99de7299dac"
            ),
            bundledByDefault: false
        ),
        ModelChoice(
            id: "tiny-en",
            title: "Tiny English",
            detail: "fastest English smoke test",
            benchmarkSummary: "Accuracy 3/5, speed 5/5, memory 5/5. 97.5% on the clean benchmark; 0.61s median; about 220 MB peak RAM.",
            accuracyRating: 3,
            speedRating: 5,
            memoryRating: 5,
            englishAsset: ModelAsset(
                filename: "ggml-tiny.en.bin",
                diskSizeText: "77.7 MB",
                downloadSizeText: "77.7 MB",
                expectedSHA1: "c78c86eb1a8faa21b369bcd33207cc90d64ae9df"
            ),
            multilingualAsset: ModelAsset(
                filename: "ggml-tiny.bin",
                diskSizeText: "77.7 MB",
                downloadSizeText: "77.7 MB",
                expectedSHA1: "bd577a113a864445d4c299885e0cb97d4ba92b5f"
            ),
            bundledByDefault: false
        )
    ]

    static var defaultChoice: ModelChoice {
        all[0]
    }

    static func choice(for id: String?) -> ModelChoice {
        all.first { $0.id == id } ?? defaultChoice
    }
}
enum ModelStore {
    static var bundledModelsURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Models", isDirectory: true)
    }

    static var userModelsURL: URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportURL
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    static func bundledURL(for choice: ModelChoice) -> URL {
        bundledURL(for: choice, inputLanguage: .defaultChoice)
    }

    static func bundledURL(for choice: ModelChoice, inputLanguage: InputLanguageChoice) -> URL {
        bundledModelsURL.appendingPathComponent(choice.filename(for: inputLanguage))
    }

    static func userURL(for choice: ModelChoice) -> URL {
        userURL(for: choice, inputLanguage: .defaultChoice)
    }

    static func userURL(for choice: ModelChoice, inputLanguage: InputLanguageChoice) -> URL {
        userModelsURL.appendingPathComponent(choice.filename(for: inputLanguage))
    }

    static func installedURL(for choice: ModelChoice) -> URL? {
        installedURL(for: choice, inputLanguage: .defaultChoice)
    }

    static func installedURL(for choice: ModelChoice, inputLanguage: InputLanguageChoice) -> URL? {
        let bundled = bundledURL(for: choice, inputLanguage: inputLanguage)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let user = userURL(for: choice, inputLanguage: inputLanguage)
        if FileManager.default.fileExists(atPath: user.path) {
            return user
        }

        return nil
    }

    static func isInstalled(_ choice: ModelChoice) -> Bool {
        installedURL(for: choice) != nil
    }

    static func isInstalled(_ choice: ModelChoice, inputLanguage: InputLanguageChoice) -> Bool {
        installedURL(for: choice, inputLanguage: inputLanguage) != nil
    }

    static func installDownloadedModel(from temporaryURL: URL, for choice: ModelChoice) throws {
        try installDownloadedModel(from: temporaryURL, for: choice, inputLanguage: .defaultChoice)
    }

    static func installDownloadedModel(
        from temporaryURL: URL,
        for choice: ModelChoice,
        inputLanguage: InputLanguageChoice
    ) throws {
        try FileManager.default.createDirectory(at: userModelsURL, withIntermediateDirectories: true)
        let destinationURL = userURL(for: choice, inputLanguage: inputLanguage)
        let partialURL = destinationURL.appendingPathExtension("download")

        if FileManager.default.fileExists(atPath: partialURL.path) {
            try FileManager.default.removeItem(at: partialURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: partialURL)
        let actualSHA1 = try sha1Hex(for: partialURL)
        let expectedSHA1 = choice.expectedSHA1(for: inputLanguage)
        guard actualSHA1 == expectedSHA1 else {
            try? FileManager.default.removeItem(at: partialURL)
            throw LocalWhispererError.modelDownloadFailed(
                "Checksum mismatch for \(choice.friendlyTitle). Expected \(expectedSHA1), got \(actualSHA1)."
            )
        }

        try FileManager.default.moveItem(at: partialURL, to: destinationURL)
    }

    private static func sha1Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
