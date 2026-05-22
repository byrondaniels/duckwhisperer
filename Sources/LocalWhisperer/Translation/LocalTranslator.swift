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
        return try translate(text, from: "en", to: targetCode)
    }

    static func translate(_ text: String, from sourceCode: String, to targetCode: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, sourceCode != targetCode else {
            return text
        }

        let runtime = try translationRuntime()
        let process = Process()
        process.executableURL = runtime.pythonURL
        process.arguments = [runtime.scriptURL.path, "--from", sourceCode, "--to", targetCode]

        var environment = ProcessInfo.processInfo.environment
        environment["ARGOS_DEVICE_TYPE"] = "cpu"
        environment["XDG_DATA_HOME"] = runtime.dataHomeURL.path
        environment["XDG_CACHE_HOME"] = runtime.cacheHomeURL.path
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
            throw LocalWhispererError.translationFailed(message)
        }

        return output.isEmpty ? text : output
    }

    private static func translationRuntime() throws -> Runtime {
        let scriptURL = Bundle.main.resourceURL!
            .appendingPathComponent("Translation/translate_local.py")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw LocalWhispererError.translationRuntimeMissing(scriptURL.path)
        }

        let supportRootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Translation", isDirectory: true)
        let developmentRootURL = URL(fileURLWithPath: "/Users/byrondaniels/src/automations/local-whisperer")

        let candidates = [
            Runtime(
                pythonURL: supportRootURL.appendingPathComponent(".venv/bin/python"),
                scriptURL: scriptURL,
                dataHomeURL: supportRootURL.appendingPathComponent("Data", isDirectory: true),
                cacheHomeURL: supportRootURL.appendingPathComponent("Cache", isDirectory: true)
            ),
            Runtime(
                pythonURL: developmentRootURL.appendingPathComponent(".translation-venv/bin/python"),
                scriptURL: scriptURL,
                dataHomeURL: developmentRootURL.appendingPathComponent("Resources/Translation/Data", isDirectory: true),
                cacheHomeURL: developmentRootURL.appendingPathComponent("Resources/Translation/Cache", isDirectory: true)
            )
        ]

        guard let runtime = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.pythonURL.path)
        }) else {
            throw LocalWhispererError.translationRuntimeMissing(
                supportRootURL.appendingPathComponent(".venv/bin/python").path
            )
        }

        guard FileManager.default.fileExists(atPath: runtime.dataHomeURL.path) else {
            throw LocalWhispererError.translationModelMissing(runtime.dataHomeURL.path)
        }

        return runtime
    }
}
