import Darwin
import Foundation

func runSmokeTranscriptionIfRequested() {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--smoke-transcribe"),
          arguments.indices.contains(flagIndex + 1)
    else {
        return
    }

    do {
        let audioURL = URL(fileURLWithPath: arguments[flagIndex + 1])
        let modelID: String?
        if let modelIndex = arguments.firstIndex(of: "--model-id"),
           arguments.indices.contains(modelIndex + 1) {
            modelID = arguments[modelIndex + 1]
        } else {
            modelID = nil
        }
        let outputLanguageID: String?
        if let outputIndex = arguments.firstIndex(of: "--output-language"),
           arguments.indices.contains(outputIndex + 1) {
            outputLanguageID = arguments[outputIndex + 1]
        } else {
            outputLanguageID = nil
        }
        let inputLanguageID: String?
        if let inputIndex = arguments.firstIndex(of: "--input-language"),
           arguments.indices.contains(inputIndex + 1) {
            inputLanguageID = arguments[inputIndex + 1]
        } else {
            inputLanguageID = nil
        }
        let writingProfileID: String?
        if let profileIndex = arguments.firstIndex(of: "--writing-profile"),
           arguments.indices.contains(profileIndex + 1) {
            writingProfileID = arguments[profileIndex + 1]
        } else {
            writingProfileID = nil
        }
        let styleIntensityPercent: Int
        if let intensityIndex = arguments.firstIndex(of: "--style-intensity"),
           arguments.indices.contains(intensityIndex + 1),
           let percent = Int(arguments[intensityIndex + 1]) {
            styleIntensityPercent = StyleIntensityChoice.choice(for: percent).percent
        } else {
            styleIntensityPercent = StyleIntensityChoice.defaultChoice.percent
        }
        let choice = ModelChoice.choice(for: modelID)
        let inputLanguage = InputLanguageChoice.choice(for: inputLanguageID)
        let outputLanguage = OutputLanguage.choice(for: outputLanguageID)
        let writingProfile = WritingProfile.choice(for: writingProfileID)
        guard let modelURL = ModelStore.installedURL(for: choice, inputLanguage: inputLanguage) else {
            throw DuckWhispererError.modelMissing(ModelStore.userURL(for: choice, inputLanguage: inputLanguage).path)
        }
        let transcriber = WhisperTranscriber(modelURL: modelURL)
        transcriber.setLanguageCode(inputLanguage.whisperCode)
        let samples = try AudioCapture.samples(from: audioURL)
        let shouldTranslateAudioToEnglish = TranscriptionOutputPipeline.shouldUseWhisperEnglishTranslation(
            inputLanguage: inputLanguage,
            outputLanguage: outputLanguage
        )
        let transcript = try transcriber.transcribe(
            samples: samples,
            translateToEnglish: shouldTranslateAudioToEnglish
        )
        let translatedOutput = try TranscriptionOutputPipeline.applyConfiguredOutputLanguage(
            to: transcript,
            inputLanguage: inputLanguage,
            outputLanguage: outputLanguage,
            preferAppleSystemTranslation: false
        )
        let output: String
        if translatedOutput.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
            output = LanguageOutputRenderer.render(
                translatedOutput,
                outputLanguage: outputLanguage,
                styleIntensityPercent: styleIntensityPercent
            )
        } else {
            output = translatedOutput
        }
        print(WritingProfileRenderer.render(output, profile: writingProfile))
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
func captureDebugPasteTextIfRequested() {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--debug-paste-text"),
          arguments.indices.contains(flagIndex + 1)
    else {
        return
    }
    debugPasteText = arguments[flagIndex + 1]
}
