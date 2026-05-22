import Foundation

struct TranslationPackChoice: Equatable {
    let id: String
    let title: String
    let sourceCode: String
    let targetCode: String
    let detail: String
    let packageFilename: String
    let packageDirectoryName: String
    let downloadSizeText: String

    var packageURL: URL {
        URL(string: "https://argos-net.com/v1/\(packageFilename)")!
    }

    static let all: [TranslationPackChoice] = [
        TranslationPackChoice(
            id: "translation-fr",
            title: "French Output",
            sourceCode: "en",
            targetCode: "fr",
            detail: "English speech -> French text",
            packageFilename: "translate-en_fr-1_9.argosmodel",
            packageDirectoryName: "translate-en_fr-1_9",
            downloadSizeText: "62 MB"
        ),
        TranslationPackChoice(
            id: "translation-nl",
            title: "Dutch Output",
            sourceCode: "en",
            targetCode: "nl",
            detail: "English speech -> Dutch text",
            packageFilename: "translate-en_nl-1_8.argosmodel",
            packageDirectoryName: "translate-en_nl-1_8",
            downloadSizeText: "68 MB"
        )
    ]

    static func choice(for id: String?) -> TranslationPackChoice? {
        all.first { $0.id == id }
    }
}
enum TranslationStore {
    private static let argosTranslateRequirement = "argostranslate==1.11.0"
    private static let sentencePieceRequirement = "sentencepiece==0.2.1"

    static var supportRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Translation", isDirectory: true)
    }

    static var venvURL: URL {
        supportRootURL.appendingPathComponent(".venv", isDirectory: true)
    }

    static var pythonURL: URL {
        venvURL.appendingPathComponent("bin/python")
    }

    static var dataHomeURL: URL {
        supportRootURL.appendingPathComponent("Data", isDirectory: true)
    }

    static var cacheHomeURL: URL {
        supportRootURL.appendingPathComponent("Cache", isDirectory: true)
    }

    static var packageDownloadsURL: URL {
        supportRootURL.appendingPathComponent("Packages", isDirectory: true)
    }

    static func isInstalled(_ pack: TranslationPackChoice) -> Bool {
        let metadataURL = dataHomeURL
            .appendingPathComponent("argos-translate/packages", isDirectory: true)
            .appendingPathComponent(pack.packageDirectoryName, isDirectory: true)
            .appendingPathComponent("metadata.json")

        return FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && FileManager.default.fileExists(atPath: metadataURL.path)
    }

    static func install(_ pack: TranslationPackChoice) throws {
        try FileManager.default.createDirectory(at: packageDownloadsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dataHomeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheHomeURL, withIntermediateDirectories: true)

        try ensureRuntime()

        let packageURL = packageDownloadsURL.appendingPathComponent(pack.packageFilename)
        try download(pack.packageURL, to: packageURL)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let installScript = "import sys; from argostranslate import package; package.install_from_path(sys.argv[1])"
        try run(
            pythonURL,
            arguments: ["-c", installScript, packageURL.path],
            environment: translationEnvironment()
        )
    }

    private static func ensureRuntime() throws {
        if FileManager.default.isExecutableFile(atPath: pythonURL.path),
           !isSupportedPython(pythonURL),
           !argostranslateIsAvailable() {
            try FileManager.default.removeItem(at: venvURL)
        }

        if !FileManager.default.isExecutableFile(atPath: pythonURL.path) {
            let hostPython = try hostPythonURL()
            try run(hostPython, arguments: ["-m", "venv", venvURL.path])
        }

        if !argostranslateIsAvailable() {
            do {
                try run(
                    pythonURL,
                    arguments: [
                        "-m", "pip", "install",
                        "--no-cache-dir",
                        "--only-binary=:all:",
                        argosTranslateRequirement,
                        sentencePieceRequirement
                    ]
                )
            } catch {
                throw LocalWhispererError.translationInstallFailed(
                    "\(error.localizedDescription)\n\nInstall Homebrew Python 3.13 or 3.12, then rerun scripts/setup_local_translation.sh."
                )
            }
        }
    }

    private static func hostPythonURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/opt/python@3.13/bin/python3.13",
            "/opt/homebrew/bin/python3.13",
            "/usr/local/opt/python@3.13/bin/python3.13",
            "/usr/local/bin/python3.13",
            "/opt/homebrew/opt/python@3.12/bin/python3.12",
            "/opt/homebrew/bin/python3.12",
            "/usr/local/opt/python@3.12/bin/python3.12",
            "/usr/local/bin/python3.12",
            "/opt/homebrew/opt/python@3.11/bin/python3.11",
            "/opt/homebrew/bin/python3.11",
            "/usr/local/opt/python@3.11/bin/python3.11",
            "/usr/local/bin/python3.11",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        if let path = candidates.first(where: {
            let url = URL(fileURLWithPath: $0)
            return FileManager.default.isExecutableFile(atPath: $0) && isSupportedPython(url)
        }) {
            return URL(fileURLWithPath: path)
        }

        throw LocalWhispererError.translationInstallFailed("Could not find Python 3.11, 3.12, or 3.13 to create the translation environment. Install one with Homebrew, for example: brew install python@3.13")
    }

    private static func isSupportedPython(_ pythonURL: URL) -> Bool {
        do {
            try run(
                pythonURL,
                arguments: [
                    "-c",
                    "import sys; sys.exit(0 if (3, 11) <= sys.version_info[:2] < (3, 14) else 1)"
                ]
            )
            return true
        } catch {
            return false
        }
    }

    private static func argostranslateIsAvailable() -> Bool {
        do {
            try run(pythonURL, arguments: ["-c", "import argostranslate"])
            return true
        } catch {
            return false
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
                result = .failure(LocalWhispererError.translationInstallFailed("HTTP \(response.statusCode) while downloading \(sourceURL.lastPathComponent)."))
                return
            }
            guard let temporaryURL else {
                result = .failure(LocalWhispererError.translationInstallFailed("No downloaded translation package was returned."))
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

    private static func translationEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["ARGOS_DEVICE_TYPE"] = "cpu"
        environment["XDG_DATA_HOME"] = dataHomeURL.path
        environment["XDG_CACHE_HOME"] = cacheHomeURL.path
        return environment
    }

    private static func run(_ executableURL: URL, arguments: [String], environment: [String: String]? = nil) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment ?? ProcessInfo.processInfo.environment

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
            throw LocalWhispererError.translationInstallFailed(
                errorOutput.isEmpty ? "\(executableURL.lastPathComponent) exited with \(process.terminationStatus)." : errorOutput
            )
        }
    }
}
