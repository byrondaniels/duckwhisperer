import CryptoKit
import Darwin
import Foundation

struct StyleRewritePack: Equatable {
    let id: String
    let title: String
    let detail: String
    let modelFilename: String
    let modelURL: URL
    let expectedModelSHA256: String
    let expectedModelSizeBytes: Int64
    let modelSizeText: String
    let runnerSizeText: String

    var totalSizeText: String {
        "\(modelSizeText) model + \(runnerSizeText) runner"
    }

    static let enhancedRobot = StyleRewritePack(
        id: "enhanced-robot",
        title: "Enhanced Robot",
        detail: "Model-powered robot rewrite. Runs locally with llama.cpp.",
        modelFilename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
        modelURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf")!,
        expectedModelSHA256: "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db",
        expectedModelSizeBytes: 491_400_032,
        modelSizeText: "491 MB",
        runnerSizeText: "8 MB"
    )
}

enum StyleRewriteStore {
    private struct RunnerArchive {
        let filename: String
        let url: URL
        let expectedSHA256: String
    }

    static var supportRootURL: URL {
        appSupportRootURL()
            .appendingPathComponent("StyleRewriter", isDirectory: true)
    }

    static var downloadsURL: URL {
        supportRootURL.appendingPathComponent("Downloads", isDirectory: true)
    }

    static var runnerURL: URL {
        supportRootURL
            .appendingPathComponent("Runner", isDirectory: true)
            .appendingPathComponent("llama-cli")
    }

    static var modelsURL: URL {
        supportRootURL.appendingPathComponent("Models", isDirectory: true)
    }

    static func modelURL(for pack: StyleRewritePack) -> URL {
        modelsURL.appendingPathComponent(pack.modelFilename)
    }

    static func isRunnerInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: runnerURL.path)
            || fallbackRunnerURL() != nil
    }

    static func isModelInstalled(_ pack: StyleRewritePack = .enhancedRobot) -> Bool {
        FileManager.default.fileExists(atPath: modelURL(for: pack).path)
    }

    static func isInstalled(_ pack: StyleRewritePack = .enhancedRobot) -> Bool {
        isRunnerInstalled() && isModelInstalled(pack)
    }

    static func statusText(for pack: StyleRewritePack = .enhancedRobot) -> String {
        if isInstalled(pack) {
            return "Installed"
        }
        if !isRunnerInstalled() && !isModelInstalled(pack) {
            return "Needs runner and model"
        }
        if !isRunnerInstalled() {
            return "Needs runner"
        }
        return "Needs model"
    }

    static func installedRunnerURL() throws -> URL {
        if FileManager.default.isExecutableFile(atPath: runnerURL.path) {
            return runnerURL
        }
        if let fallback = fallbackRunnerURL() {
            return fallback
        }
        throw LocalWhispererError.styleRewriteRuntimeMissing("Install Enhanced Robot from Speed & Accuracy.")
    }

    static func install(_ pack: StyleRewritePack = .enhancedRobot) throws {
        if !isRunnerInstalled() {
            try installRunner()
        }
        if !isModelInstalled(pack) {
            try installModel(pack)
        }
    }

    private static func fallbackRunnerURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["PLUME_LLAMA_CLI"],
            environment["DUCKWHISPERER_LLAMA_CLI"],
            "/opt/homebrew/bin/llama-cli",
            "/usr/local/bin/llama-cli",
            "/opt/homebrew/bin/llama",
            "/usr/local/bin/llama"
        ].compactMap { $0 }

        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func installRunner() throws {
        let archive = try runnerArchive()
        try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        let archiveURL = downloadsURL.appendingPathComponent(archive.filename)
        try download(archive.url, to: archiveURL)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let actualSHA256 = try sha256Hex(for: archiveURL)
        guard actualSHA256 == archive.expectedSHA256 else {
            throw LocalWhispererError.styleRewriteInstallFailed(
                "Checksum mismatch for llama.cpp runner. Expected \(archive.expectedSHA256), got \(actualSHA256)."
            )
        }

        let extractionURL = downloadsURL.appendingPathComponent("llama-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: extractionURL) }

        try run(URL(fileURLWithPath: "/usr/bin/tar"), arguments: ["-xzf", archiveURL.path, "-C", extractionURL.path])

        guard let extractedRunnerURL = findFile(named: "llama-cli", under: extractionURL) else {
            throw LocalWhispererError.styleRewriteInstallFailed("The llama.cpp archive did not contain llama-cli.")
        }

        let extractedRunnerDirectory = extractedRunnerURL.deletingLastPathComponent()
        let runnerDirectory = runnerURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: runnerDirectory.path) {
            try FileManager.default.removeItem(at: runnerDirectory)
        }
        try FileManager.default.createDirectory(
            at: runnerDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: extractedRunnerDirectory, to: runnerDirectory)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runnerURL.path)
        try? run(URL(fileURLWithPath: "/usr/bin/xattr"), arguments: ["-dr", "com.apple.quarantine", runnerDirectory.path])
    }

    private static func installModel(_ pack: StyleRewritePack) throws {
        try FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        let destinationURL = modelURL(for: pack)
        let partialURL = destinationURL.appendingPathExtension("download")
        if FileManager.default.fileExists(atPath: partialURL.path) {
            try FileManager.default.removeItem(at: partialURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try download(pack.modelURL, to: partialURL)
        let fileSize = try FileManager.default.attributesOfItem(atPath: partialURL.path)[.size] as? NSNumber
        guard fileSize?.int64Value == pack.expectedModelSizeBytes else {
            try? FileManager.default.removeItem(at: partialURL)
            throw LocalWhispererError.styleRewriteInstallFailed(
                "Downloaded rewrite model had an unexpected size. Expected \(pack.expectedModelSizeBytes) bytes, got \(fileSize?.int64Value ?? 0)."
            )
        }

        let actualSHA256 = try sha256Hex(for: partialURL)
        guard actualSHA256 == pack.expectedModelSHA256 else {
            try? FileManager.default.removeItem(at: partialURL)
            throw LocalWhispererError.styleRewriteInstallFailed(
                "Checksum mismatch for \(pack.modelFilename). Expected \(pack.expectedModelSHA256), got \(actualSHA256)."
            )
        }
        try FileManager.default.moveItem(at: partialURL, to: destinationURL)
    }

    private static func runnerArchive() throws -> RunnerArchive {
        let baseURL = "https://github.com/ggml-org/llama.cpp/releases/download/b9060"
        switch ProcessInfo.processInfo.machineHardwareName {
        case "arm64":
            let filename = "llama-b9060-bin-macos-arm64.tar.gz"
            return RunnerArchive(
                filename: filename,
                url: URL(string: "\(baseURL)/\(filename)")!,
                expectedSHA256: "dd89c0428d99fbcdbe39406cbfce56e2d5fb1b46d93047055ba576ea6d12fbaa"
            )
        case "x86_64":
            let filename = "llama-b9060-bin-macos-x64.tar.gz"
            return RunnerArchive(
                filename: filename,
                url: URL(string: "\(baseURL)/\(filename)")!,
                expectedSHA256: "79c7ca2465cbebd1ef22fdaceea14108beb8943555fc2eccfd7f741a64bb8e30"
            )
        default:
            throw LocalWhispererError.styleRewriteInstallFailed("Unsupported Mac architecture: \(ProcessInfo.processInfo.machineHardwareName).")
        }
    }

    private static func download(_ sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<URL, Error>!

        URLSession.shared.downloadTask(with: sourceURL) { temporaryURL, response, error in
            defer { semaphore.signal() }

            if let error {
                result = .failure(error)
                return
            }
            if let response = response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                result = .failure(LocalWhispererError.styleRewriteInstallFailed("HTTP \(response.statusCode) while downloading \(sourceURL.lastPathComponent)."))
                return
            }
            guard let temporaryURL else {
                result = .failure(LocalWhispererError.styleRewriteInstallFailed("No downloaded file was returned."))
                return
            }

            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                result = .success(destinationURL)
            } catch {
                result = .failure(error)
            }
        }.resume()

        semaphore.wait()
        _ = try result.get()
    }

    private static func findFile(named filename: String, under rootURL: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == filename {
            return fileURL
        }
        return nil
    }

    private static func sha256Hex(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func run(_ executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        if let nullOutput = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null")) {
            process.standardOutput = nullOutput
        }

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LocalWhispererError.styleRewriteInstallFailed(
                errorOutput.isEmpty ? "\(executableURL.lastPathComponent) exited with \(process.terminationStatus)." : errorOutput
            )
        }
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
