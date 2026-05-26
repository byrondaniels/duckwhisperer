import Foundation

enum LocalStyleRewriter {
    private static let timeoutSeconds: TimeInterval = 35

    static func robot(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return text
        }

        let runnerURL = try StyleRewriteStore.installedRunnerURL()
        let modelURL = StyleRewriteStore.modelURL(for: .enhancedRobot)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw DuckWhispererError.styleRewriteRuntimeMissing("Install the Enhanced Robot model from Speed & Accuracy.")
        }

        let prompt = robotPrompt(for: trimmed)
        let output = try run(
            runnerURL: runnerURL,
            modelURL: modelURL,
            prompt: prompt
        )
        let cleaned = clean(output)
        return cleaned.isEmpty ? text : cleaned
    }

    private static func robotPrompt(for text: String) -> String {
        """
        <|im_start|>system
        Rewrite text in a crisp retro robot voice.
        Preserve the exact meaning, names, numbers, links, tasks, and instructions.
        Do not add new facts.
        Do not explain yourself.
        Return only the rewritten text.
        Keep it about the same length.
        <|im_end|>
        <|im_start|>user
        \(text)
        <|im_end|>
        <|im_start|>assistant
        """
    }

    private static func run(runnerURL: URL, modelURL: URL, prompt: String) throws -> String {
        let process = Process()
        process.executableURL = runnerURL
        process.currentDirectoryURL = runnerURL.deletingLastPathComponent()
        process.arguments = [
            "-m", modelURL.path,
            "-p", prompt,
            "-n", "220",
            "--ctx-size", "4096",
            "--temp", "0.35",
            "--top-p", "0.9",
            "--no-conversation",
            "--no-display-prompt",
            "--no-show-timings",
            "--no-warmup",
            "--simple-io",
            "--log-disable"
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["GGML_METAL_NO_RESIDENCY"] = "1"
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        if let nullError = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null")) {
            process.standardError = nullError
        }

        try process.run()
        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            waitGroup.leave()
        }

        if waitGroup.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            process.waitUntilExit()
            throw DuckWhispererError.styleRewriteFailed("The local robot model timed out.")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw DuckWhispererError.styleRewriteFailed("llama-cli exited with \(process.terminationStatus).")
        }

        return output
    }

    private static func clean(_ output: String) -> String {
        var cleaned = output
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            "assistant:",
            "rewritten text:",
            "output:"
        ]
        for prefix in prefixes where cleaned.localizedCaseInsensitiveContains(prefix) {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if cleaned.hasPrefix("\""), cleaned.hasSuffix("\""), cleaned.count > 1 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
