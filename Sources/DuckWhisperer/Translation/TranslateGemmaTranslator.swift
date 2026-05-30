import Foundation

enum TranslateGemmaTranslator {
    static func translate(
        _ text: String,
        from sourceCode: String = "en",
        to targetCode: String,
        using pack: TranslationPackChoice
    ) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, sourceCode != targetCode else {
            return text
        }

        guard case .translateGemmaMLX(_) = pack.backend else {
            throw DuckWhispererError.translationFailed("\(pack.title) is not a TranslateGemma fallback pack.")
        }

        let modelURL = TranslationStore.localURL(for: pack)
        guard TranslationStore.isInstalled(pack) else {
            throw DuckWhispererError.translationModelMissing(modelURL.path)
        }

        let scriptURL = Bundle.main.resourceURL!
            .appendingPathComponent("Translation/translate_gemma_mlx.py")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw DuckWhispererError.translationRuntimeMissing(scriptURL.path)
        }

        let process = Process()
        process.executableURL = TranslationStore.translateGemmaPythonURL
        process.arguments = [
            scriptURL.path,
            "--from", sourceCode,
            "--to", targetCode,
            "--model-dir", modelURL.path
        ]
        process.environment = TranslationStore.translateGemmaEnvironment()

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        if let inputData = trimmed.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
        }
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorOutput.isEmpty ? "TranslateGemma exited with \(process.terminationStatus)." : errorOutput
            throw DuckWhispererError.translationFailed(message)
        }

        return output.isEmpty ? text : output
    }
}
