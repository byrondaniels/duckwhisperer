import CryptoKit
import Foundation

struct ModelChoice: Equatable {
    let id: String
    let title: String
    let filename: String
    let detail: String
    let diskSizeText: String
    let downloadSizeText: String
    let benchmarkSummary: String
    let accuracyRating: Int
    let speedRating: Int
    let memoryRating: Int
    let expectedSHA1: String
    let bundledByDefault: Bool

    var relativePath: String {
        "Models/\(filename)"
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }

    static let all: [ModelChoice] = [
        ModelChoice(
            id: "small-en",
            title: "Small English - Recommended",
            filename: "ggml-small.en.bin",
            detail: "best default for English dictation",
            diskSizeText: "487.6 MB",
            downloadSizeText: "487.6 MB",
            benchmarkSummary: "Accuracy 5/5, speed 3/5, memory 3/5. 98.3% on the dictation benchmark; 1.95s median for 47.5s audio; about 713 MB peak RAM.",
            accuracyRating: 5,
            speedRating: 3,
            memoryRating: 3,
            expectedSHA1: "db8a495a91d927739e50b3fc1cc4c6b8f6c2d022",
            bundledByDefault: false
        ),
        ModelChoice(
            id: "base-en",
            title: "Base English",
            filename: "ggml-base.en.bin",
            detail: "fast English dictation",
            diskSizeText: "148.0 MB",
            downloadSizeText: "148.0 MB",
            benchmarkSummary: "Accuracy 4/5, speed 4/5, memory 4/5. 97.5% on the dictation benchmark; 1.04s median; about 311 MB peak RAM.",
            accuracyRating: 4,
            speedRating: 4,
            memoryRating: 4,
            expectedSHA1: "137c40403d78fd54d454da0f9bd998f78703390c",
            bundledByDefault: false
        ),
        ModelChoice(
            id: "tiny-en",
            title: "Tiny English",
            filename: "ggml-tiny.en.bin",
            detail: "fastest English smoke test",
            diskSizeText: "77.7 MB",
            downloadSizeText: "77.7 MB",
            benchmarkSummary: "Accuracy 3/5, speed 5/5, memory 5/5. 97.5% on the clean benchmark; 0.61s median; about 220 MB peak RAM.",
            accuracyRating: 3,
            speedRating: 5,
            memoryRating: 5,
            expectedSHA1: "c78c86eb1a8faa21b369bcd33207cc90d64ae9df",
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
        bundledModelsURL.appendingPathComponent(choice.filename)
    }

    static func userURL(for choice: ModelChoice) -> URL {
        userModelsURL.appendingPathComponent(choice.filename)
    }

    static func installedURL(for choice: ModelChoice) -> URL? {
        let bundled = bundledURL(for: choice)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let user = userURL(for: choice)
        if FileManager.default.fileExists(atPath: user.path) {
            return user
        }

        return nil
    }

    static func isInstalled(_ choice: ModelChoice) -> Bool {
        installedURL(for: choice) != nil
    }

    static func installDownloadedModel(from temporaryURL: URL, for choice: ModelChoice) throws {
        try FileManager.default.createDirectory(at: userModelsURL, withIntermediateDirectories: true)
        let destinationURL = userURL(for: choice)
        let partialURL = destinationURL.appendingPathExtension("download")

        if FileManager.default.fileExists(atPath: partialURL.path) {
            try FileManager.default.removeItem(at: partialURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: partialURL)
        let actualSHA1 = try sha1Hex(for: partialURL)
        guard actualSHA1 == choice.expectedSHA1 else {
            try? FileManager.default.removeItem(at: partialURL)
            throw LocalWhispererError.modelDownloadFailed(
                "Checksum mismatch for \(choice.title). Expected \(choice.expectedSHA1), got \(actualSHA1)."
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
