import Foundation

enum TranslationPackBackend: Equatable {
    case argos
    case huggingFaceMarian(modelID: String)
}

struct TranslationPackChoice: Equatable {
    let id: String
    let title: String
    let sourceCode: String
    let targetCode: String
    let detail: String
    let backend: TranslationPackBackend
    let packageFilename: String?
    let packageDirectoryName: String
    let downloadSizeText: String

    var packageURL: URL? {
        guard let packageFilename else {
            return nil
        }
        return URL(string: "https://argos-net.com/v1/\(packageFilename)")!
    }

    var isInputToEnglishPack: Bool {
        sourceCode != "en" && targetCode == "en"
    }

    init(
        id: String,
        title: String,
        sourceCode: String,
        targetCode: String,
        detail: String,
        packageFilename: String,
        packageDirectoryName: String,
        downloadSizeText: String
    ) {
        self.id = id
        self.title = title
        self.sourceCode = sourceCode
        self.targetCode = targetCode
        self.detail = detail
        self.backend = .argos
        self.packageFilename = packageFilename
        self.packageDirectoryName = packageDirectoryName
        self.downloadSizeText = downloadSizeText
    }

    init(
        id: String,
        title: String,
        sourceCode: String,
        targetCode: String,
        detail: String,
        huggingFaceModelID: String,
        packageDirectoryName: String,
        downloadSizeText: String
    ) {
        self.id = id
        self.title = title
        self.sourceCode = sourceCode
        self.targetCode = targetCode
        self.detail = detail
        self.backend = .huggingFaceMarian(modelID: huggingFaceModelID)
        self.packageFilename = nil
        self.packageDirectoryName = packageDirectoryName
        self.downloadSizeText = downloadSizeText
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
        ),
        TranslationPackChoice(
            id: "translation-fr-en",
            title: "French -> English",
            sourceCode: "fr",
            targetCode: "en",
            detail: "French speech -> English text",
            packageFilename: "translate-fr_en-1_9.argosmodel",
            packageDirectoryName: "translate-fr_en-1_9",
            downloadSizeText: "62 MB"
        ),
        TranslationPackChoice(
            id: "translation-nl-en",
            title: "Dutch -> English",
            sourceCode: "nl",
            targetCode: "en",
            detail: "Dutch speech -> English text",
            packageFilename: "translate-nl_en-1_8.argosmodel",
            packageDirectoryName: "translate-nl_en-1_8",
            downloadSizeText: "68 MB"
        ),
        TranslationPackChoice.helsinki("es", "Spanish", "Helsinki-NLP/opus-mt-es-en", "312 MB"),
        TranslationPackChoice.helsinki("tl", "Tagalog", "Helsinki-NLP/opus-mt-tl-en", "296 MB"),
        TranslationPackChoice.helsinki("zh", "Chinese", "Helsinki-NLP/opus-mt-zh-en", "312 MB"),
        TranslationPackChoice.helsinki("hi", "Hindi", "Helsinki-NLP/opus-mt-hi-en", "304 MB"),
        TranslationPackChoice.helsinki("ar", "Arabic", "Helsinki-NLP/opus-mt-ar-en", "about 310 MB"),
        TranslationPackChoice.helsinki("bn", "Bengali", "Helsinki-NLP/opus-mt-bn-en", "about 310 MB"),
        TranslationPackChoice.helsinki("pt", "Portuguese", "Helsinki-NLP/opus-mt-ROMANCE-en", "about 310 MB"),
        TranslationPackChoice.helsinki("ru", "Russian", "Helsinki-NLP/opus-mt-ru-en", "307 MB"),
        TranslationPackChoice.helsinki("ur", "Urdu", "Helsinki-NLP/opus-mt-ur-en", "306 MB"),
        TranslationPackChoice.helsinki("id", "Indonesian", "Helsinki-NLP/opus-mt-id-en", "about 310 MB"),
        TranslationPackChoice.helsinki("de", "German", "Helsinki-NLP/opus-mt-de-en", "about 310 MB"),
        TranslationPackChoice.helsinki("ja", "Japanese", "Helsinki-NLP/opus-mt-ja-en", "303 MB"),
        TranslationPackChoice.helsinki("ko", "Korean", "Helsinki-NLP/opus-mt-ko-en", "312 MB"),
        TranslationPackChoice.helsinki("tr", "Turkish", "Helsinki-NLP/opus-mt-tr-en", "about 310 MB"),
        TranslationPackChoice.helsinki("vi", "Vietnamese", "Helsinki-NLP/opus-mt-vi-en", "about 310 MB"),
        TranslationPackChoice.helsinki("it", "Italian", "Helsinki-NLP/opus-mt-it-en", "344 MB"),
        TranslationPackChoice.helsinki("pl", "Polish", "Helsinki-NLP/opus-mt-pl-en", "309 MB")
    ]

    static func helsinki(_ sourceCode: String, _ title: String, _ modelID: String, _ downloadSizeText: String) -> TranslationPackChoice {
        TranslationPackChoice(
            id: "translation-\(sourceCode)-en",
            title: "\(title) -> English",
            sourceCode: sourceCode,
            targetCode: "en",
            detail: "\(title) speech -> English text",
            huggingFaceModelID: modelID,
            packageDirectoryName: modelID
                .replacingOccurrences(of: "/", with: "__")
                .replacingOccurrences(of: " ", with: "-"),
            downloadSizeText: downloadSizeText
        )
    }

    static func choice(for id: String?) -> TranslationPackChoice? {
        all.first { $0.id == id }
    }

    static func choice(sourceCode: String, targetCode: String) -> TranslationPackChoice? {
        all.first { $0.sourceCode == sourceCode && $0.targetCode == targetCode }
    }

    static func visiblePacks(for inputLanguage: InputLanguageChoice) -> [TranslationPackChoice] {
        var packs: [TranslationPackChoice] = []
        if !inputLanguage.isEnglish,
           let inputPack = choice(sourceCode: inputLanguage.whisperCode, targetCode: "en") {
            packs.append(inputPack)
        }
        packs.append(contentsOf: all.filter { $0.sourceCode == "en" })
        return packs
    }
}
enum TranslationStore {
    private static let argosTranslateRequirement = "argostranslate==1.11.0"
    private static let sentencePieceRequirement = "sentencepiece==0.2.1"
    private static let transformersRequirement = "transformers>=4.42,<5"
    private static let torchRequirement = "torch>=2.3,<3"
    private static let huggingFaceHubRequirement = "huggingface_hub>=0.23,<1"
    private static let sacremosesRequirement = "sacremoses>=0.1,<1"

    static var supportRootURL: URL {
        appSupportRootURL()
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

    static var huggingFaceModelsURL: URL {
        supportRootURL.appendingPathComponent("HuggingFace", isDirectory: true)
    }

    static func localURL(for pack: TranslationPackChoice) -> URL {
        switch pack.backend {
        case .argos:
            return dataHomeURL
                .appendingPathComponent("argos-translate/packages", isDirectory: true)
                .appendingPathComponent(pack.packageDirectoryName, isDirectory: true)
        case .huggingFaceMarian(_):
            return huggingFaceModelsURL.appendingPathComponent(pack.packageDirectoryName, isDirectory: true)
        }
    }

    static func isInstalled(_ pack: TranslationPackChoice) -> Bool {
        switch pack.backend {
        case .argos:
            return isArgosPackInstalled(pack)
        case .huggingFaceMarian(_):
            return isHuggingFacePackInstalled(pack)
        }
    }

    private static func isArgosPackInstalled(_ pack: TranslationPackChoice) -> Bool {
        let metadataURL = dataHomeURL
            .appendingPathComponent("argos-translate/packages", isDirectory: true)
            .appendingPathComponent(pack.packageDirectoryName, isDirectory: true)
            .appendingPathComponent("metadata.json")

        return FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && FileManager.default.fileExists(atPath: metadataURL.path)
    }

    private static func isHuggingFacePackInstalled(_ pack: TranslationPackChoice) -> Bool {
        let modelURL = localURL(for: pack)
        let hasWeights = FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("pytorch_model.bin").path)
            || FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("model.safetensors").path)
        return FileManager.default.isExecutableFile(atPath: pythonURL.path)
            && FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("config.json").path)
            && FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("source.spm").path)
            && FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("target.spm").path)
            && hasWeights
    }

    static func install(_ pack: TranslationPackChoice) throws {
        try FileManager.default.createDirectory(at: packageDownloadsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dataHomeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheHomeURL, withIntermediateDirectories: true)

        switch pack.backend {
        case .argos:
            try installArgosPack(pack)
        case .huggingFaceMarian(let modelID):
            try installHuggingFacePack(pack, modelID: modelID)
        }
    }

    private static func installArgosPack(_ pack: TranslationPackChoice) throws {
        guard let packageFilename = pack.packageFilename else {
            throw PlumeError.translationInstallFailed("Missing package filename for \(pack.title).")
        }

        try ensureArgosRuntime()

        let packageURL = packageDownloadsURL.appendingPathComponent(packageFilename)
        guard let remotePackageURL = pack.packageURL else {
            throw PlumeError.translationInstallFailed("Missing package URL for \(pack.title).")
        }
        try download(remotePackageURL, to: packageURL)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let installScript = "import sys; from argostranslate import package; package.install_from_path(sys.argv[1])"
        try run(
            pythonURL,
            arguments: ["-c", installScript, packageURL.path],
            environment: translationEnvironment()
        )
    }

    private static func installHuggingFacePack(_ pack: TranslationPackChoice, modelID: String) throws {
        try ensureHuggingFaceRuntime()
        try FileManager.default.createDirectory(at: huggingFaceModelsURL, withIntermediateDirectories: true)

        let destinationURL = localURL(for: pack)
        let temporaryURL = huggingFaceModelsURL.appendingPathComponent("\(pack.packageDirectoryName).download-\(UUID().uuidString)", isDirectory: true)
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }

        let installScript = """
        import sys
        from pathlib import Path
        from huggingface_hub import hf_hub_download

        repo_id = sys.argv[1]
        destination = Path(sys.argv[2])
        destination.mkdir(parents=True, exist_ok=True)

        required_files = [
            "config.json",
            "pytorch_model.bin",
            "source.spm",
            "target.spm",
            "vocab.json",
        ]
        optional_files = [
            "generation_config.json",
            "tokenizer_config.json",
        ]

        for filename in required_files:
            hf_hub_download(repo_id=repo_id, filename=filename, local_dir=str(destination))

        for filename in optional_files:
            try:
                hf_hub_download(repo_id=repo_id, filename=filename, local_dir=str(destination))
            except Exception:
                pass
        """

        do {
            try run(
                pythonURL,
                arguments: ["-c", installScript, modelID, temporaryURL.path],
                environment: translationEnvironment()
            )
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private static func ensurePythonRuntime() throws {
        if FileManager.default.isExecutableFile(atPath: pythonURL.path),
           !isSupportedPython(pythonURL) {
            try FileManager.default.removeItem(at: venvURL)
        }

        if !FileManager.default.isExecutableFile(atPath: pythonURL.path) {
            let hostPython = try hostPythonURL()
            try run(hostPython, arguments: ["-m", "venv", venvURL.path])
        }
    }

    private static func ensureArgosRuntime() throws {
        try ensurePythonRuntime()

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
                throw PlumeError.translationInstallFailed(
                    "\(error.localizedDescription)\n\nInstall Homebrew Python 3.13 or 3.12, then rerun scripts/setup_local_translation.sh."
                )
            }
        }
    }

    private static func ensureHuggingFaceRuntime() throws {
        try ensurePythonRuntime()

        if !huggingFaceTranslatorIsAvailable() {
            do {
                try run(
                    pythonURL,
                    arguments: [
                        "-m", "pip", "install",
                        "--no-cache-dir",
                        "--only-binary=:all:",
                        transformersRequirement,
                        torchRequirement,
                        huggingFaceHubRequirement,
                        sentencePieceRequirement,
                        sacremosesRequirement
                    ]
                )
            } catch {
                throw PlumeError.translationInstallFailed(
                    "\(error.localizedDescription)\n\nInstall Homebrew Python 3.13 or 3.12, then try installing the translator again."
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

        throw PlumeError.translationInstallFailed("Could not find Python 3.11, 3.12, or 3.13 to create the translation environment. Install one with Homebrew, for example: brew install python@3.13")
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

    private static func huggingFaceTranslatorIsAvailable() -> Bool {
        do {
            try run(pythonURL, arguments: ["-c", "import torch, transformers, huggingface_hub, sentencepiece"])
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
                result = .failure(PlumeError.translationInstallFailed("HTTP \(response.statusCode) while downloading \(sourceURL.lastPathComponent)."))
                return
            }
            guard let temporaryURL else {
                result = .failure(PlumeError.translationInstallFailed("No downloaded translation package was returned."))
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
        environment["HF_HOME"] = cacheHomeURL.appendingPathComponent("huggingface", isDirectory: true).path
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
            throw PlumeError.translationInstallFailed(
                errorOutput.isEmpty ? "\(executableURL.lastPathComponent) exited with \(process.terminationStatus)." : errorOutput
            )
        }
    }
}
