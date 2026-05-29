import Foundation

enum TranscriptionOutputPipeline {
    static func shouldProduceEnglishBase(outputLanguage: OutputLanguage) -> Bool {
        outputLanguage.isEnglishLanguage
            || outputLanguage.requiresTranslation
            || (!outputLanguage.isSameAsInput && outputLanguage.languageCode == nil)
    }

    static func requiredTranslationPacks(
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage
    ) -> [TranslationPackChoice] {
        guard !outputLanguage.matchesInput(inputLanguage) else {
            return []
        }

        var packs: [TranslationPackChoice] = []
        if !inputLanguage.isEnglish,
           shouldProduceEnglishBase(outputLanguage: outputLanguage),
           let sourceToEnglish = TranslationPackChoice.choice(
               sourceCode: inputLanguage.whisperCode,
               targetCode: "en"
           ) {
            packs.append(sourceToEnglish)
        }

        if let targetCode = outputLanguage.translationTargetCode,
           AppleSystemTranslator.shouldHandle(
                sourceCode: "en",
                targetCode: targetCode,
                requestedPackID: outputLanguage.translationPackID
           ) {
            return packs
        }

        if let englishToTarget = englishToTargetPack(for: outputLanguage) {
            packs.append(englishToTarget)
        }

        return packs.reduce(into: []) { uniquePacks, pack in
            if !uniquePacks.contains(where: { $0.id == pack.id }) {
                uniquePacks.append(pack)
            }
        }
    }

    static func shouldUseWhisperEnglishTranslation(
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage
    ) -> Bool {
        guard !inputLanguage.isEnglish else {
            return false
        }
        guard !outputLanguage.matchesInput(inputLanguage) else {
            return false
        }
        guard shouldProduceEnglishBase(outputLanguage: outputLanguage) else {
            return false
        }
        guard let sourceToEnglish = TranslationPackChoice.choice(sourceCode: inputLanguage.whisperCode, targetCode: "en") else {
            return true
        }
        return !TranslationStore.isInstalled(sourceToEnglish)
    }

    static func applyConfiguredOutputLanguage(
        to text: String,
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage,
        preferAppleSystemTranslation: Bool = true
    ) throws -> String {
        if outputLanguage.matchesInput(inputLanguage) {
            return text
        }

        var englishBaseText = text
        if !inputLanguage.isEnglish,
           shouldProduceEnglishBase(outputLanguage: outputLanguage),
           let sourceToEnglish = TranslationPackChoice.choice(sourceCode: inputLanguage.whisperCode, targetCode: "en"),
           TranslationStore.isInstalled(sourceToEnglish) {
            englishBaseText = try LocalTranslator.translate(text, from: inputLanguage.whisperCode, to: "en")
        }

        if outputLanguage.isEnglishLanguage || (!outputLanguage.requiresTranslation && outputLanguage.languageCode == nil) {
            return englishBaseText
        }

        if outputLanguage.requiresTranslation {
            if preferAppleSystemTranslation,
               let targetCode = outputLanguage.translationTargetCode,
               AppleSystemTranslator.shouldHandle(
                    sourceCode: "en",
                    targetCode: targetCode,
                    requestedPackID: outputLanguage.translationPackID
               ) {
                do {
                    return try AppleSystemTranslator.translate(englishBaseText, from: "en", to: targetCode)
                } catch {
                    AppLog.write("Apple system translation failed for en -> \(targetCode): \(error.localizedDescription)")
                }
            }
            return try LocalTranslator.translate(englishBaseText, to: outputLanguage)
        }

        return englishBaseText
    }

    private static func englishToTargetPack(for outputLanguage: OutputLanguage) -> TranslationPackChoice? {
        guard let targetCode = outputLanguage.translationTargetCode else {
            return nil
        }
        if let packID = outputLanguage.translationPackID,
           let pack = TranslationPackChoice.choice(for: packID),
           pack.sourceCode == "en",
           pack.targetCode == targetCode {
            return pack
        }
        return TranslationPackChoice.choice(sourceCode: "en", targetCode: targetCode)
    }
}
