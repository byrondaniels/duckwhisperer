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
        let writingProfileID: String?
        if let profileIndex = arguments.firstIndex(of: "--writing-profile"),
           arguments.indices.contains(profileIndex + 1) {
            writingProfileID = arguments[profileIndex + 1]
        } else {
            writingProfileID = nil
        }
        let choice = ModelChoice.choice(for: modelID)
        let outputLanguage = OutputLanguage.choice(for: outputLanguageID)
        let writingProfile = WritingProfile.choice(for: writingProfileID)
        guard let modelURL = ModelStore.installedURL(for: choice) else {
            throw LocalWhispererError.modelMissing(ModelStore.userURL(for: choice).path)
        }
        let transcriber = WhisperTranscriber(modelURL: modelURL)
        let samples = try AudioCapture.samples(from: audioURL)
        let transcript = try transcriber.transcribe(samples: samples)
        let translatedOutput = try LocalTranslator.translate(transcript, to: outputLanguage)
        let output: String
        if translatedOutput.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
            switch outputLanguage.id {
            case "british":
                output = StyledSpeech.british(translatedOutput)
            case "genz":
                output = StyledSpeech.genZ(translatedOutput)
            case "duck":
                output = DuckSpeech.render(translatedOutput)
            default:
                output = translatedOutput
            }
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
