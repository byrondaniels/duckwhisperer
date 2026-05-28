import Foundation

enum LocalTranslator {
    private struct Runtime {
        let pythonURL: URL
        let scriptURL: URL
        let dataHomeURL: URL
        let cacheHomeURL: URL
    }

    static func translate(_ text: String, to outputLanguage: OutputLanguage) throws -> String {
        guard let targetCode = outputLanguage.translationTargetCode else {
            return text
        }
        let requestedPack = outputLanguage.translationPackID.flatMap { TranslationPackChoice.choice(for: $0) }
        return try translate(text, from: "en", to: targetCode, using: requestedPack)
    }

    static func translate(
        _ text: String,
        from sourceCode: String,
        to targetCode: String,
        using requestedPack: TranslationPackChoice? = nil
    ) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, sourceCode != targetCode else {
            return text
        }

        let runtime = try translationRuntime()
        let pack: TranslationPackChoice?
        if let requestedPack,
           requestedPack.sourceCode == sourceCode,
           requestedPack.targetCode == targetCode {
            pack = requestedPack
        } else {
            pack = TranslationPackChoice.choice(sourceCode: sourceCode, targetCode: targetCode)
        }
        let process = Process()
        process.executableURL = runtime.pythonURL
        var arguments = [runtime.scriptURL.path, "--from", sourceCode, "--to", targetCode]
        if let pack, case .huggingFaceMarian(_) = pack.backend {
            let modelURL = TranslationStore.localURL(for: pack)
            guard TranslationStore.isInstalled(pack) else {
                throw DuckWhispererError.translationModelMissing(modelURL.path)
            }
            arguments.append(contentsOf: ["--hf-model-dir", modelURL.path])
            if let sourcePrefix = pack.sourcePrefix {
                arguments.append(contentsOf: ["--source-prefix", sourcePrefix])
            }
        }
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["ARGOS_DEVICE_TYPE"] = "cpu"
        environment["XDG_DATA_HOME"] = runtime.dataHomeURL.path
        environment["XDG_CACHE_HOME"] = runtime.cacheHomeURL.path
        environment["HF_HOME"] = runtime.cacheHomeURL.appendingPathComponent("huggingface", isDirectory: true).path
        process.environment = environment

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

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorOutput.isEmpty ? "local translator exited with \(process.terminationStatus)" : errorOutput
            throw DuckWhispererError.translationFailed(message)
        }

        return output.isEmpty ? text : output
    }

    private static func translationRuntime() throws -> Runtime {
        let scriptURL = Bundle.main.resourceURL!
            .appendingPathComponent("Translation/translate_local.py")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw DuckWhispererError.translationRuntimeMissing(scriptURL.path)
        }

        let supportRootURL = TranslationStore.supportRootURL
        var candidates = [
            Runtime(
                pythonURL: supportRootURL.appendingPathComponent(".venv/bin/python"),
                scriptURL: scriptURL,
                dataHomeURL: supportRootURL.appendingPathComponent("Data", isDirectory: true),
                cacheHomeURL: supportRootURL.appendingPathComponent("Cache", isDirectory: true)
            )
        ]

        let environment = ProcessInfo.processInfo.environment
        let overrideRoot = environment["DUCKWHISPERER_TRANSLATION_ROOT"] ?? environment["PLUME_TRANSLATION_ROOT"]
        if let overrideRoot = overrideRoot,
           !overrideRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let overrideRootURL = URL(fileURLWithPath: overrideRoot, isDirectory: true)
            candidates.insert(
                Runtime(
                    pythonURL: overrideRootURL.appendingPathComponent(".venv/bin/python"),
                    scriptURL: scriptURL,
                    dataHomeURL: overrideRootURL.appendingPathComponent("Data", isDirectory: true),
                    cacheHomeURL: overrideRootURL.appendingPathComponent("Cache", isDirectory: true)
                ),
                at: 0
            )
        }

        guard let runtime = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.pythonURL.path)
        }) else {
            throw DuckWhispererError.translationRuntimeMissing(
                supportRootURL.appendingPathComponent(".venv/bin/python").path
            )
        }

        return runtime
    }
}
