import AppKit
import Foundation
import Translation

enum AppleSystemTranslator {
    static func shouldHandle(sourceCode: String, targetCode: String, requestedPackID: String?) -> Bool {
        guard requestedPackID == nil else {
            return false
        }
        guard sourceCode == "en", ["fr", "nl"].contains(targetCode) else {
            return false
        }
        if #available(macOS 26.0, *) {
            return NSApp.isRunning
        }
        return false
    }

    static func translate(_ text: String, from sourceCode: String, to targetCode: String) throws -> String {
        guard !Thread.isMainThread else {
            throw DuckWhispererError.translationFailed("Apple system translation cannot run synchronously on the main thread.")
        }
        guard shouldHandle(sourceCode: sourceCode, targetCode: targetCode, requestedPackID: nil) else {
            throw DuckWhispererError.translationFailed("Apple system translation is unavailable for \(sourceCode) -> \(targetCode).")
        }

        let normalized = OfficeTranslationContext.normalizeEnglishSource(text)
        let translated = try runSynchronously {
            try await translateAsync(normalized, from: sourceCode, to: targetCode)
        }
        return OfficeTranslationContext.cleanTranslatedOutput(translated, targetCode: targetCode)
    }

    @available(macOS 26.0, *)
    private static func translateAsync(_ text: String, from sourceCode: String, to targetCode: String) async throws -> String {
        let source = Locale.Language(identifier: sourceCode)
        let target = Locale.Language(identifier: targetCode)
        let session: TranslationSession
        if #available(macOS 26.4, *) {
            session = TranslationSession(
                installedSource: source,
                target: target,
                preferredStrategy: .highFidelity
            )
        } else {
            session = TranslationSession(installedSource: source, target: target)
        }
        let response = try await session.translate(text)
        return response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runSynchronously(_ operation: @escaping () async throws -> String) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?

        Task {
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()
        guard let result else {
            throw DuckWhispererError.translationFailed("Apple system translation did not return a result.")
        }
        return try result.get()
    }
}
