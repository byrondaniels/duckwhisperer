import Foundation

enum TranscriptionOutputPipeline {
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
        return outputLanguage.isEnglishLanguage || outputLanguage.requiresTranslation
    }

    static func applyConfiguredOutputLanguage(
        to text: String,
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage
    ) throws -> String {
        if outputLanguage.matchesInput(inputLanguage) || outputLanguage.isEnglishLanguage {
            return text
        }

        if outputLanguage.requiresTranslation {
            return try LocalTranslator.translate(text, to: outputLanguage)
        }

        return text
    }
}
