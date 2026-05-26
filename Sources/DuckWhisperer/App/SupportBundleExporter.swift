import ApplicationServices
import AVFoundation
import Foundation

enum SupportBundleExporter {
    static func suggestedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "DuckWhisperer-Support-\(formatter.string(from: Date())).zip"
    }

    static func export(
        to destinationURL: URL,
        selectedModel: ModelChoice,
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage,
        writingProfile: WritingProfile
    ) throws {
        let fileManager = FileManager.default
        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("DuckWhisperer-Support-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: stagingURL)
        }

        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try diagnosticsText(
            selectedModel: selectedModel,
            inputLanguage: inputLanguage,
            outputLanguage: outputLanguage,
            writingProfile: writingProfile
        ).write(
            to: stagingURL.appendingPathComponent("diagnostics.txt"),
            atomically: true,
            encoding: .utf8
        )

        if fileManager.fileExists(atPath: AppLog.url.path) {
            try fileManager.copyItem(
                at: AppLog.url,
                to: stagingURL.appendingPathComponent(logFilename)
            )
        }

        if let infoURL = Bundle.main.url(forResource: "Info", withExtension: "plist") {
            try? fileManager.copyItem(
                at: infoURL,
                to: stagingURL.appendingPathComponent("Info.plist")
            )
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try zip(stagingURL: stagingURL, destinationURL: destinationURL)
    }

    private static func diagnosticsText(
        selectedModel: ModelChoice,
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage,
        writingProfile: WritingProfile
    ) -> String {
        let microphoneStatus: String
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = "authorized"
        case .denied:
            microphoneStatus = "denied"
        case .restricted:
            microphoneStatus = "restricted"
        case .notDetermined:
            microphoneStatus = "not determined"
        @unknown default:
            microphoneStatus = "unknown"
        }

        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let stats = DictationStatsStore.current()
        let pasteReadiness = PasteTargetDetector.readiness()
        let installedModelPath = ModelStore.installedURL(for: selectedModel, inputLanguage: inputLanguage)?.path ?? "missing"

        return """
        DuckWhisperer Support Diagnostics
        Generated: \(ISO8601DateFormatter().string(from: Date()))

        App
        Version: \(version)
        Build: \(build)
        Bundle ID: \(bundle.bundleIdentifier ?? "unknown")
        Executable: \(bundle.executableURL?.path ?? "unknown")

        System
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Host: \(Host.current().localizedName ?? "unknown")

        Permissions
        Microphone: \(microphoneStatus)
        Paste-back accessibility: \(AXIsProcessTrusted() ? "trusted" : "not trusted")
        Paste-back status: \(pasteReadiness.title)
        Paste-back detail: \(pasteReadiness.detail)

        Settings
        Model: \(selectedModel.friendlyTitle)
        Model path: \(installedModelPath)
        Input language: \(inputLanguage.title)
        Output language: \(outputLanguage.effectiveTitle(for: inputLanguage))
        Writing mode: \(writingProfile.title)

        Stats
        Dictations: \(stats.completedDictations)
        Words dictated: \(stats.wordsDictated)
        Time saved: \(stats.savedTimeText)

        Paths
        App support: \(appSupportRootURL().path)
        User models: \(ModelStore.userModelsURL.path)
        Bundled models: \(ModelStore.bundledModelsURL.path)
        Log: \(AppLog.url.path)

        Privacy note
        This bundle intentionally excludes transcript history and saved-word contents.
        """
    }

    private static func zip(stagingURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            stagingURL.path,
            destinationURL.path
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? "ditto failed"
            throw DuckWhispererError.supportBundleFailed("Could not create archive: \(message)")
        }
    }
}
