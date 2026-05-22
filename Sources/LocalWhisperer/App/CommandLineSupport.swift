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
        let choice = ModelChoice.choice(for: modelID)
        let outputLanguage = OutputLanguage.choice(for: outputLanguageID)
        guard let modelURL = ModelStore.installedURL(for: choice) else {
            throw LocalWhispererError.modelMissing(ModelStore.userURL(for: choice).path)
        }
        let transcriber = WhisperTranscriber(modelURL: modelURL)
        let samples = try AudioCapture.samples(from: audioURL)
        let transcript = try transcriber.transcribe(samples: samples)
        let translatedOutput = try LocalTranslator.translate(transcript, to: outputLanguage)
        let output = outputLanguage.id == "duck"
            ? DuckSpeech.render(translatedOutput)
            : translatedOutput
        print(output)
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
