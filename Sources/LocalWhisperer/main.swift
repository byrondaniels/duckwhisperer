import AppKit
import ApplicationServices
import AVFoundation
import Carbon.HIToolbox
import CryptoKit
import Foundation
import QuartzCore
import whisper

private let hotKeySignature = fourCharCode("LWSP")
private let hotKeyIdentifier: UInt32 = 1
private let selectedModelIDKey = "SelectedModelID"
private let selectedOutputLanguageIDKey = "SelectedOutputLanguageID"
private let preserveCapitalizationKey = "PreserveCapitalization"
private let appDisplayName = "DuckWhisperer"
private let supportDirectoryName = "Local Whisperer"
private let logFilename = "duckwhisperer.log"
private let buildMarker = "duckwhisperer-2026-05-21-duck-output"
private var globalHotKeyAction: (() -> Void)?
private var debugPasteText: String?

private enum AppLog {
    static func write(_ message: String) {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
        let logURL = supportURL.appendingPathComponent(logFilename)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"

        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logURL.path) {
                try Data().write(to: logURL)
            }
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            fputs("\(appDisplayName) log failed: \(error.localizedDescription)\n", stderr)
        }
    }
}

private struct ModelChoice: Equatable {
    let id: String
    let title: String
    let filename: String
    let detail: String
    let diskSizeText: String
    let downloadSizeText: String
    let benchmarkSummary: String
    let accuracyRating: Int
    let speedRating: Int
    let memoryRating: Int
    let expectedSHA1: String
    let bundledByDefault: Bool

    var relativePath: String {
        "Models/\(filename)"
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }

    static let all: [ModelChoice] = [
        ModelChoice(
            id: "small-en",
            title: "Small English - Recommended",
            filename: "ggml-small.en.bin",
            detail: "best default for English dictation",
            diskSizeText: "487.6 MB",
            downloadSizeText: "487.6 MB",
            benchmarkSummary: "Accuracy 5/5, speed 3/5, memory 3/5. 98.3% on the dictation benchmark; 1.95s median for 47.5s audio; about 713 MB peak RAM.",
            accuracyRating: 5,
            speedRating: 3,
            memoryRating: 3,
            expectedSHA1: "db8a495a91d927739e50b3fc1cc4c6b8f6c2d022",
            bundledByDefault: false
        ),
        ModelChoice(
            id: "base-en",
            title: "Base English",
            filename: "ggml-base.en.bin",
            detail: "fast English dictation",
            diskSizeText: "148.0 MB",
            downloadSizeText: "148.0 MB",
            benchmarkSummary: "Accuracy 4/5, speed 4/5, memory 4/5. 97.5% on the dictation benchmark; 1.04s median; about 311 MB peak RAM.",
            accuracyRating: 4,
            speedRating: 4,
            memoryRating: 4,
            expectedSHA1: "137c40403d78fd54d454da0f9bd998f78703390c",
            bundledByDefault: false
        ),
        ModelChoice(
            id: "tiny-en",
            title: "Tiny English",
            filename: "ggml-tiny.en.bin",
            detail: "fastest English smoke test",
            diskSizeText: "77.7 MB",
            downloadSizeText: "77.7 MB",
            benchmarkSummary: "Accuracy 3/5, speed 5/5, memory 5/5. 97.5% on the clean benchmark; 0.61s median; about 220 MB peak RAM.",
            accuracyRating: 3,
            speedRating: 5,
            memoryRating: 5,
            expectedSHA1: "c78c86eb1a8faa21b369bcd33207cc90d64ae9df",
            bundledByDefault: false
        )
    ]

    static var defaultChoice: ModelChoice {
        all[0]
    }

    static func choice(for id: String?) -> ModelChoice {
        all.first { $0.id == id } ?? defaultChoice
    }
}

private enum ModelStore {
    static var bundledModelsURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Models", isDirectory: true)
    }

    static var userModelsURL: URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return supportURL
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    static func bundledURL(for choice: ModelChoice) -> URL {
        bundledModelsURL.appendingPathComponent(choice.filename)
    }

    static func userURL(for choice: ModelChoice) -> URL {
        userModelsURL.appendingPathComponent(choice.filename)
    }

    static func installedURL(for choice: ModelChoice) -> URL? {
        let bundled = bundledURL(for: choice)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let user = userURL(for: choice)
        if FileManager.default.fileExists(atPath: user.path) {
            return user
        }

        return nil
    }

    static func isInstalled(_ choice: ModelChoice) -> Bool {
        installedURL(for: choice) != nil
    }

    static func installDownloadedModel(from temporaryURL: URL, for choice: ModelChoice) throws {
        try FileManager.default.createDirectory(at: userModelsURL, withIntermediateDirectories: true)
        let destinationURL = userURL(for: choice)
        let partialURL = destinationURL.appendingPathExtension("download")

        if FileManager.default.fileExists(atPath: partialURL.path) {
            try FileManager.default.removeItem(at: partialURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: partialURL)
        let actualSHA1 = try sha1Hex(for: partialURL)
        guard actualSHA1 == choice.expectedSHA1 else {
            try? FileManager.default.removeItem(at: partialURL)
            throw LocalWhispererError.modelDownloadFailed(
                "Checksum mismatch for \(choice.title). Expected \(choice.expectedSHA1), got \(actualSHA1)."
            )
        }

        try FileManager.default.moveItem(at: partialURL, to: destinationURL)
    }

    private static func sha1Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct OutputLanguage: Equatable {
    let id: String
    let title: String
    let translationTargetCode: String?

    var requiresTranslation: Bool {
        translationTargetCode != nil
    }

    static let all: [OutputLanguage] = [
        OutputLanguage(id: "en", title: "English", translationTargetCode: nil),
        OutputLanguage(id: "fr", title: "French", translationTargetCode: "fr"),
        OutputLanguage(id: "nl", title: "Dutch", translationTargetCode: "nl"),
        OutputLanguage(id: "duck", title: "Duck", translationTargetCode: nil)
    ]

    static var defaultChoice: OutputLanguage {
        all[0]
    }

    static func choice(for id: String?) -> OutputLanguage {
        all.first { $0.id == id } ?? defaultChoice
    }
}

private struct TranslationPackChoice: Equatable {
    let id: String
    let title: String
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
            targetCode: "fr",
            detail: "English speech -> French text",
            packageFilename: "translate-en_fr-1_9.argosmodel",
            packageDirectoryName: "translate-en_fr-1_9",
            downloadSizeText: "62 MB"
        ),
        TranslationPackChoice(
            id: "translation-nl",
            title: "Dutch Output",
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

private enum TranslationStore {
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
        if !FileManager.default.isExecutableFile(atPath: pythonURL.path) {
            let hostPython = try hostPythonURL()
            try run(hostPython, arguments: ["-m", "venv", venvURL.path])
        }

        if !argostranslateIsAvailable() {
            try run(
                pythonURL,
                arguments: ["-m", "pip", "install", "--no-cache-dir", "argostranslate==1.9.6"]
            )
        }
    }

    private static func hostPythonURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/opt/python@3.11/bin/python3.11",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3.11",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        throw LocalWhispererError.translationInstallFailed("Could not find a local Python 3 runtime to create the translation environment.")
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

private func fourCharCode(_ value: String) -> OSType {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + scalar.value
    }
    return result
}

private let hotKeyEventHandler: EventHandlerUPP = { _, eventRef, _ in
    guard let eventRef else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr, hotKeyID.signature == hotKeySignature, hotKeyID.id == hotKeyIdentifier {
        DispatchQueue.main.async {
            globalHotKeyAction?()
        }
    }

    return noErr
}

private enum DuckIcon {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            drawDuckSilhouette(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawDuckSilhouette(in rect: NSRect) {
        let w = rect.width
        let h = rect.height
        NSColor.black.setFill()

        NSBezierPath(ovalIn: NSRect(x: w * 0.10, y: h * 0.28, width: w * 0.58, height: h * 0.38)).fill()
        NSBezierPath(ovalIn: NSRect(x: w * 0.56, y: h * 0.54, width: w * 0.28, height: h * 0.28)).fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: w * 0.80, y: h * 0.66))
        beak.line(to: NSPoint(x: w * 0.98, y: h * 0.61))
        beak.line(to: NSPoint(x: w * 0.80, y: h * 0.56))
        beak.close()
        beak.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: w * 0.15, y: h * 0.49))
        tail.line(to: NSPoint(x: w * 0.01, y: h * 0.61))
        tail.line(to: NSPoint(x: w * 0.05, y: h * 0.43))
        tail.close()
        tail.fill()

        let water = NSBezierPath(roundedRect: NSRect(x: w * 0.12, y: h * 0.14, width: w * 0.70, height: h * 0.10), xRadius: h * 0.05, yRadius: h * 0.05)
        water.fill()
    }
}

private enum AppState: Equatable {
    case ready
    case recording
    case transcribing
    case error(String)

    var statusText: String {
        switch self {
        case .ready:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

}

private final class HotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(action: @escaping () -> Void) -> OSStatus {
        globalHotKeyAction = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            return handlerStatus
        }

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        return RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

private final class AudioCapture {
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Double(WHISPER_SAMPLE_RATE),
        channels: 1,
        interleaved: false
    )!
    private let lock = NSLock()
    private let conversionLock = NSLock()
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var isRecording = false

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw LocalWhispererError.audioReadFailed("No microphone input format was available.")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw LocalWhispererError.audioReadFailed("Could not create the microphone sample-rate converter.")
        }

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        isRecording = true
        lock.unlock()

        self.engine = engine
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.appendConvertedSamples(from: buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            lock.lock()
            isRecording = false
            lock.unlock()
            self.engine = nil
            self.converter = nil
            throw error
        }
    }

    func stop() throws -> [Float] {
        lock.lock()
        let wasRecording = isRecording
        lock.unlock()

        guard wasRecording, let engine else {
            throw LocalWhispererError.noRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        flushConvertedSamples()

        lock.lock()
        isRecording = false
        lock.unlock()

        self.engine = nil
        self.converter = nil

        return snapshotSamples()
    }

    func snapshotSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    func sampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    private func appendConvertedSamples(from buffer: AVAudioPCMBuffer) {
        guard let converter else {
            return
        }

        let inputRate = buffer.format.sampleRate
        let outputRate = targetFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(
            max(1, ceil(Double(buffer.frameLength) * outputRate / inputRate) + 32)
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else {
            return
        }

        conversionLock.lock()
        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        conversionLock.unlock()

        guard status != .error else {
            return
        }

        appendSamples(from: convertedBuffer)
    }

    private func flushConvertedSamples() {
        guard let converter,
              let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: AVAudioFrameCount(Int(WHISPER_SAMPLE_RATE) / 2)
              )
        else {
            return
        }

        conversionLock.lock()
        defer { conversionLock.unlock() }

        for _ in 0..<8 {
            var conversionError: NSError?
            let status: AVAudioConverterOutputStatus = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                outStatus.pointee = .endOfStream
                return nil
            }

            guard status != .error else {
                return
            }

            appendSamples(from: convertedBuffer)

            if status == .endOfStream || convertedBuffer.frameLength == 0 {
                return
            }
        }
    }

    private func appendSamples(from buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0,
              let channel = buffer.floatChannelData?[0]
        else {
            return
        }

        let newSamples = Array(UnsafeBufferPointer(
            start: channel,
            count: Int(buffer.frameLength)
        ))

        lock.lock()
        if isRecording {
            samples.append(contentsOf: newSamples)
        }
        lock.unlock()
    }

    static func samples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            throw LocalWhispererError.audioReadFailed("Could not allocate audio buffer.")
        }

        try file.read(into: buffer)

        guard buffer.frameLength > 0,
              file.processingFormat.commonFormat == .pcmFormatFloat32,
              file.processingFormat.channelCount == 1,
              abs(file.processingFormat.sampleRate - Double(WHISPER_SAMPLE_RATE)) < 1,
              let channel = buffer.floatChannelData?[0]
        else {
            throw LocalWhispererError.audioReadFailed(
                "Recording was not 16 kHz mono float PCM. Format: \(file.processingFormat)"
            )
        }

        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

private final class RecordingOverlayView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let container = bounds.insetBy(dx: 1, dy: 1)
        let background = NSBezierPath(roundedRect: container, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.88).setFill()
        background.fill()

        drawBird()
    }

    private func drawBird() {
        let body = NSBezierPath(ovalIn: NSRect(x: 45, y: 29, width: 43, height: 27))
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        body.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 76, y: 18, width: 24, height: 24))
        head.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 47, y: 38))
        tail.line(to: NSPoint(x: 28, y: 27))
        tail.line(to: NSPoint(x: 36, y: 41))
        tail.line(to: NSPoint(x: 28, y: 53))
        tail.close()
        tail.fill()

        let beak = NSBezierPath()
        beak.move(to: NSPoint(x: 98, y: 27))
        beak.line(to: NSPoint(x: 111, y: 31))
        beak.line(to: NSPoint(x: 98, y: 36))
        beak.close()
        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.22, alpha: 1).setFill()
        beak.fill()

        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 88, y: 26, width: 4, height: 4)).fill()

        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 58, y: 41))
        wing.curve(
            to: NSPoint(x: 78, y: 39),
            controlPoint1: NSPoint(x: 62, y: 29),
            controlPoint2: NSPoint(x: 74, y: 30)
        )
        wing.curve(
            to: NSPoint(x: 58, y: 41),
            controlPoint1: NSPoint(x: 75, y: 50),
            controlPoint2: NSPoint(x: 64, y: 53)
        )
        NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
        wing.fill()

        NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.22, alpha: 1).setStroke()
        let leftFoot = NSBezierPath()
        leftFoot.lineWidth = 2
        leftFoot.move(to: NSPoint(x: 61, y: 56))
        leftFoot.line(to: NSPoint(x: 57, y: 62))
        leftFoot.stroke()

        let rightFoot = NSBezierPath()
        rightFoot.lineWidth = 2
        rightFoot.move(to: NSPoint(x: 74, y: 56))
        rightFoot.line(to: NSPoint(x: 78, y: 62))
        rightFoot.stroke()
    }
}

private final class RecordingOverlayController {
    private let panel: NSPanel
    private let overlayView: RecordingOverlayView
    private var isVisible = false

    init() {
        let size = NSSize(width: 140, height: 76)
        overlayView = RecordingOverlayView(frame: NSRect(origin: .zero, size: size))
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = overlayView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    func show() {
        guard !isVisible else {
            return
        }

        isVisible = true
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            self?.startPulse()
        }
    }

    func hide() {
        guard isVisible else {
            return
        }

        isVisible = false
        stopPulse()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, !self.isVisible else {
                return
            }
            self.panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height - 42
        )
        panel.setFrameOrigin(origin)
    }

    private func startPulse() {
        guard isVisible, let layer = overlayView.layer else {
            return
        }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.45
        animation.duration = 0.72
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "recording-pulse")
    }

    private func stopPulse() {
        overlayView.layer?.removeAnimation(forKey: "recording-pulse")
    }
}

private final class TranscriptionResultController: NSObject {
    private let panel: NSPanel
    private let textView = NSTextView()

    override init() {
        let size = NSSize(width: 560, height: 300)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.title = "\(appDisplayName) Transcript"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace]

        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = contentView

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyText))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closePanel))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(scrollView)
        contentView.addSubview(copyButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            copyButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
    }

    func show(text: String) {
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        if !panel.isVisible {
            centerPanel()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    private func centerPanel() {
        guard let screen = NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        ))
    }

    @objc private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func closePanel() {
        panel.orderOut(nil)
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class ModelExplorerController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let scrollView = NSScrollView()
    private let documentView = FlippedDocumentView()
    private let stackView = NSStackView()
    private var currentModel: ModelChoice
    private let onUseModel: (ModelChoice) -> Void
    private let onModelsChanged: () -> Void
    private var downloadingModelIDs = Set<String>()
    private var installingTranslationPackIDs = Set<String>()

    init(
        currentModel: ModelChoice,
        onUseModel: @escaping (ModelChoice) -> Void,
        onModelsChanged: @escaping () -> Void
    ) {
        self.currentModel = currentModel
        self.onUseModel = onUseModel
        self.onModelsChanged = onModelsChanged

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Model Explorer"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 460)
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        super.init()
        window.delegate = self
        buildWindow()
        rebuild()
    }

    func show(currentModel: ModelChoice) {
        self.currentModel = currentModel
        rebuild()
        scrollToTop()

        if !window.isVisible {
            window.setContentSize(NSSize(width: 320, height: 640))
            window.center()
        }
        AppLog.write("showing model explorer; visible before=\(window.isVisible)")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        DispatchQueue.main.async { [weak self] in
            self?.scrollToTop()
        }
        AppLog.write("showed model explorer; visible after=\(window.isVisible), key=\(window.isKeyWindow), main=\(window.isMainWindow)")
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func refresh(currentModel: ModelChoice) {
        self.currentModel = currentModel
        rebuild()
    }

    private func buildWindow() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = makeLabel("Model Explorer", font: .boldSystemFont(ofSize: 20))
        let subtitleLabel = makeLabel(
            "Downloads stay outside the app bundle and install only when you approve them.",
            font: .systemFont(ofSize: 13),
            color: .secondaryLabelColor
        )

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        documentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        documentView.addSubview(stackView)
        scrollView.documentView = documentView

        contentView.addSubview(headerStack)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: documentView.widthAnchor)
        ])
    }

    private func rebuild() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        addSectionTitle("Speech Models")
        for choice in ModelChoice.all {
            addFullWidthRow(makeModelRow(for: choice))
        }

        addSectionTitle("Output Language Packs")
        for pack in TranslationPackChoice.all {
            addFullWidthRow(makeTranslationPackRow(for: pack))
        }
    }

    private func scrollToTop() {
        scrollView.layoutSubtreeIfNeeded()
        guard let documentView = scrollView.documentView else {
            return
        }

        let topY: CGFloat
        if documentView.isFlipped {
            topY = 0
        } else {
            topY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        }

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func addSectionTitle(_ text: String) {
        let label = makeLabel(text, font: .boldSystemFont(ofSize: 13), color: .secondaryLabelColor)
        label.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(label)
        label.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func addFullWidthRow(_ row: NSView) {
        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func makeModelRow(for choice: ModelChoice) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        row.layer?.cornerRadius = 8

        let title = choice == ModelChoice.defaultChoice ? "\(choice.title) - default" : choice.title
        let titleLabel = makeLabel(title, font: .boldSystemFont(ofSize: 14))
        let detailLabel = makeLabel(choice.detail, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let statusLabel = makeLabel(
            "\(choice.diskSizeText) · \(statusText(for: choice))",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        let metricsLabel = makeLabel(
            compactBenchmarkText(for: choice),
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )

        let actionButton = NSButton(title: actionTitle(for: choice), target: self, action: #selector(handleModelAction(_:)))
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .rounded
        actionButton.identifier = NSUserInterfaceItemIdentifier(choice.id)
        actionButton.isEnabled = canAct(on: choice)

        row.addSubview(titleLabel)
        row.addSubview(detailLabel)
        row.addSubview(statusLabel)
        row.addSubview(metricsLabel)
        row.addSubview(actionButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 106),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 11),
            titleLabel.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),

            actionButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            actionButton.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            actionButton.widthAnchor.constraint(equalToConstant: 96),

            detailLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            detailLabel.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 6),

            statusLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 4),

            metricsLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            metricsLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            metricsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            metricsLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10)
        ])

        return row
    }

    private func makeTranslationPackRow(for pack: TranslationPackChoice) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        row.layer?.cornerRadius = 8

        let titleLabel = makeLabel(pack.title, font: .boldSystemFont(ofSize: 14))
        let detailLabel = makeLabel(pack.detail, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let statusLabel = makeLabel(
            "\(translationStatusText(for: pack)) · \(pack.downloadSizeText) download",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )

        let actionButton = NSButton(title: translationActionTitle(for: pack), target: self, action: #selector(handleTranslationPackAction(_:)))
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .rounded
        actionButton.identifier = NSUserInterfaceItemIdentifier(pack.id)
        actionButton.isEnabled = canAct(on: pack)

        row.addSubview(titleLabel)
        row.addSubview(detailLabel)
        row.addSubview(statusLabel)
        row.addSubview(actionButton)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 82),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 11),
            titleLabel.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),

            actionButton.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            actionButton.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            actionButton.widthAnchor.constraint(equalToConstant: 96),

            detailLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            detailLabel.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 6),

            statusLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 4),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10)
        ])

        return row
    }

    private func makeLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    private func rating(_ value: Int) -> String {
        "\(value)/5"
    }

    private func compactBenchmarkText(for choice: ModelChoice) -> String {
        switch choice.id {
        case "small-en":
            return "Acc 5/5 · Speed 3/5 · 1.95s median · ~713 MB RAM"
        case "base-en":
            return "Acc 4/5 · Speed 4/5 · 1.04s median · ~311 MB RAM"
        case "tiny-en":
            return "Acc 3/5 · Speed 5/5 · 0.61s median · ~220 MB RAM"
        default:
            return "Acc \(choice.accuracyRating)/5 · Speed \(choice.speedRating)/5 · Memory \(choice.memoryRating)/5"
        }
    }

    private func statusText(for choice: ModelChoice) -> String {
        if downloadingModelIDs.contains(choice.id) {
            return "Downloading..."
        }
        if ModelStore.installedURL(for: choice) != nil {
            return "Installed"
        }
        return "Not installed"
    }

    private func actionTitle(for choice: ModelChoice) -> String {
        if downloadingModelIDs.contains(choice.id) {
            return "Downloading..."
        }
        guard ModelStore.isInstalled(choice) else {
            return "Download"
        }
        return choice == currentModel ? "Selected" : "Use"
    }

    private func canAct(on choice: ModelChoice) -> Bool {
        if downloadingModelIDs.contains(choice.id) {
            return false
        }
        if ModelStore.isInstalled(choice), choice == currentModel {
            return false
        }
        return true
    }

    private func translationStatusText(for pack: TranslationPackChoice) -> String {
        if installingTranslationPackIDs.contains(pack.id) {
            return "Installing..."
        }
        return TranslationStore.isInstalled(pack) ? "Installed" : "Not installed"
    }

    private func translationActionTitle(for pack: TranslationPackChoice) -> String {
        if installingTranslationPackIDs.contains(pack.id) {
            return "Installing..."
        }
        return TranslationStore.isInstalled(pack) ? "Installed" : "Install"
    }

    private func canAct(on pack: TranslationPackChoice) -> Bool {
        !installingTranslationPackIDs.contains(pack.id) && !TranslationStore.isInstalled(pack)
    }

    @objc private func handleModelAction(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }
        let choice = ModelChoice.choice(for: id)

        if ModelStore.isInstalled(choice) {
            currentModel = choice
            onUseModel(choice)
            rebuild()
        } else {
            confirmAndDownload(choice)
        }
    }

    @objc private func handleTranslationPackAction(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let pack = TranslationPackChoice.choice(for: id),
              !TranslationStore.isInstalled(pack)
        else {
            return
        }

        confirmAndInstall(pack)
    }

    private func confirmAndDownload(_ choice: ModelChoice) {
        let alert = NSAlert()
        alert.messageText = "Download \(choice.title)?"
        alert.informativeText = "This will download \(choice.downloadSizeText) to \(ModelStore.userModelsURL.path). The model will not be downloaded unless you approve this."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        downloadingModelIDs.insert(choice.id)
        rebuild()

        URLSession.shared.downloadTask(with: choice.downloadURL) { [weak self] temporaryURL, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.downloadingModelIDs.remove(choice.id)

                do {
                    if let error {
                        throw LocalWhispererError.modelDownloadFailed(error.localizedDescription)
                    }
                    if let response = response as? HTTPURLResponse,
                       !(200...299).contains(response.statusCode) {
                        throw LocalWhispererError.modelDownloadFailed("HTTP \(response.statusCode) while downloading \(choice.filename).")
                    }
                    guard let temporaryURL else {
                        throw LocalWhispererError.modelDownloadFailed("No downloaded file was returned.")
                    }
                    try ModelStore.installDownloadedModel(from: temporaryURL, for: choice)
                    self.currentModel = choice
                    self.onUseModel(choice)
                    self.onModelsChanged()
                } catch {
                    self.showError(error)
                }

                self.rebuild()
            }
        }.resume()
    }

    private func confirmAndInstall(_ pack: TranslationPackChoice) {
        let alert = NSAlert()
        alert.messageText = "Install \(pack.title)?"
        alert.informativeText = "This installs \(pack.downloadSizeText) of local translation data into \(TranslationStore.supportRootURL.path). If the translator runtime is missing, \(appDisplayName) will also install it there."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        installingTranslationPackIDs.insert(pack.id)
        rebuild()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try TranslationStore.install(pack)
                DispatchQueue.main.async {
                    self?.installingTranslationPackIDs.remove(pack.id)
                    self?.rebuild()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.installingTranslationPackIDs.remove(pack.id)
                    self?.showError(error)
                    self?.rebuild()
                }
            }
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

private struct PasteTarget {
    let application: NSRunningApplication?
    let element: AXUIElement?
    let pid: pid_t?
    let selectedRange: CFRange?
}

private enum PasteTargetDetector {
    static func captureFocusedEditableTarget() -> PasteTarget {
        let application = currentExternalFrontmostApplication()
        let editableElement = focusedEditableElement()
        var pid: pid_t?

        if let editableElement {
            var elementPID = pid_t()
            if AXUIElementGetPid(editableElement, &elementPID) == .success {
                pid = elementPID
            }
        }

        let selectedRange = editableElement.flatMap { selectedTextRange(of: $0) }
        let pidText = pid.map { String($0) } ?? "nil"
        let rangeText = selectedRange.map { "\($0.location),\($0.length)" } ?? "nil"
        AppLog.write("paste target captured app=\(application?.localizedName ?? "nil") pid=\(pidText) element=\(editableElement == nil ? "nil" : "editable") range=\(rangeText)")
        return PasteTarget(application: application, element: editableElement, pid: pid, selectedRange: selectedRange)
    }

    static func canAttemptPasteIntoFocusedTarget() -> Bool {
        guard AXIsProcessTrusted(),
              let element = focusedUIElement()
        else {
            return false
        }

        return !elementBelongsToCurrentProcess(element)
    }

    static func focusCapturedTarget(_ target: PasteTarget) -> Bool {
        guard let element = target.element,
              AXIsProcessTrusted(),
              elementStillBelongsToExpectedProcess(element, target: target),
              isEditableTextTarget(element)
        else {
            AppLog.write("paste target focus restore failed before AX focus")
            return false
        }

        if let app = target.application, !app.isTerminated {
            app.activate(options: [.activateAllWindows])
        }

        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AppLog.write("paste target focus restore attempted")
        return true
    }

    static func insertTextDirectly(_ text: String, into target: PasteTarget) -> Bool {
        guard let element = target.element,
              AXIsProcessTrusted(),
              elementStillBelongsToExpectedProcess(element, target: target),
              isEditableTextTarget(element)
        else {
            AppLog.write("direct insert skipped; no captured editable AX element")
            return false
        }

        if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            AppLog.write("direct insert succeeded via AX selected text")
            return true
        }

        guard let value = stringAttribute(kAXValueAttribute as CFString, of: element) else {
            AppLog.write("direct insert failed; AX value unavailable")
            return false
        }

        let range = selectedTextRange(of: element)
            ?? target.selectedRange
            ?? CFRange(location: value.utf16.count, length: 0)
        guard range.location >= 0,
              range.length >= 0,
              range.location <= value.utf16.count,
              range.location + range.length <= value.utf16.count
        else {
            AppLog.write("direct insert failed; invalid range \(range.location),\(range.length) for length \(value.utf16.count)")
            return false
        }

        let newValue = (value as NSString).replacingCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: text
        )
        let setValueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFString)
        guard setValueResult == .success else {
            AppLog.write("direct insert failed; setting AX value returned \(setValueResult.rawValue)")
            return false
        }

        var newSelection = CFRange(location: range.location + text.utf16.count, length: 0)
        if let newSelectionValue = AXValueCreate(.cfRange, &newSelection) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, newSelectionValue)
        }

        AppLog.write("direct insert succeeded via AX value replacement")
        return true
    }

    static func hasFocusedEditableTarget() -> Bool {
        guard AXIsProcessTrusted(),
              var element = focusedUIElement()
        else {
            return false
        }

        for _ in 0..<5 {
            if isEditableTextTarget(element) {
                return true
            }

            guard let parent = parentElement(of: element) else {
                return false
            }
            element = parent
        }

        return false
    }

    static func currentExternalFrontmostApplication() -> NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }
        return application
    }

    private static func elementBelongsToCurrentProcess(_ element: AXUIElement) -> Bool {
        var pid = pid_t()
        return AXUIElementGetPid(element, &pid) == .success
            && pid == ProcessInfo.processInfo.processIdentifier
    }

    private static func elementStillBelongsToExpectedProcess(_ element: AXUIElement, target: PasteTarget) -> Bool {
        var pid = pid_t()
        guard AXUIElementGetPid(element, &pid) == .success else {
            return false
        }
        if let targetPID = target.pid {
            return pid == targetPID
        }
        return pid != ProcessInfo.processInfo.processIdentifier
    }

    private static func focusedEditableElement() -> AXUIElement? {
        guard AXIsProcessTrusted(),
              var element = focusedUIElement()
        else {
            return nil
        }

        for _ in 0..<5 {
            if isEditableTextTarget(element),
               !elementBelongsToCurrentProcess(element) {
                return element
            }

            guard let parent = parentElement(of: element) else {
                return nil
            }
            element = parent
        }

        return nil
    }

    private static func focusedUIElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func parentElement(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func isEditableTextTarget(_ element: AXUIElement) -> Bool {
        let textRoles = [
            kAXTextAreaRole as String,
            kAXTextFieldRole as String,
            kAXComboBoxRole as String
        ]

        if let role = stringAttribute(kAXRoleAttribute as CFString, of: element),
           textRoles.contains(role) {
            return true
        }

        return isAttributeSettable(kAXValueAttribute as CFString, of: element)
            && hasAttribute(kAXSelectedTextRangeAttribute as CFString, of: element)
    }

    private static func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private static func hasAttribute(_ attribute: CFString, of element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success
    }

    private static func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func isAttributeSettable(_ attribute: CFString, of element: AXUIElement) -> Bool {
        var isSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &isSettable) == .success
            && isSettable.boolValue
    }
}

private final class WhisperTranscriber {
    private var modelURL: URL
    private var context: OpaquePointer?
    private let lock = NSLock()

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    func setModelURL(_ newModelURL: URL) {
        lock.lock()
        defer { lock.unlock() }

        guard modelURL != newModelURL else {
            return
        }

        if let context {
            whisper_free(context)
            self.context = nil
        }
        modelURL = newModelURL
    }

    func transcribe(samples: [Float], initialPrompt: String? = nil, singleSegment: Bool = false) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let context = try loadedContext()
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(4, min(ProcessInfo.processInfo.processorCount - 2, 10)))
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = singleSegment
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_nst = false
        params.temperature = 0
        params.temperature_inc = 0.2
        params.entropy_thold = 2.4
        params.logprob_thold = -1.0
        params.no_speech_thold = 0.6
        params.greedy.best_of = 1

        let runTranscription: (UnsafePointer<CChar>?) -> Int32 = { promptPointer in
            params.initial_prompt = promptPointer

            let language = "en"
            return language.withCString { languagePointer in
                params.language = languagePointer
                params.detect_language = false
                return samples.withUnsafeBufferPointer { sampleBuffer in
                    guard let baseAddress = sampleBuffer.baseAddress else {
                        return 1
                    }
                    return whisper_full(context, params, baseAddress, Int32(samples.count))
                }
            }
        }

        let result: Int32
        if let initialPrompt, !initialPrompt.isEmpty {
            result = initialPrompt.withCString { promptPointer in
                runTranscription(promptPointer)
            }
        } else {
            result = runTranscription(nil)
        }

        guard result == 0 else {
            throw LocalWhispererError.transcriptionFailed("whisper_full returned \(result).")
        }

        var transcript = ""
        let segmentCount = whisper_full_n_segments(context)
        for index in 0..<segmentCount {
            if let segment = whisper_full_get_segment_text(context, index) {
                transcript += String(cString: segment)
            }
        }

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func preload() throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try loadedContext()
    }

    private func loadedContext() throws -> OpaquePointer {
        if let context {
            return context
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw LocalWhispererError.modelMissing(modelURL.path)
        }

        setenv("GGML_METAL_NO_RESIDENCY", "1", 0)

        func loadContext(useGPU: Bool) -> OpaquePointer? {
            var contextParams = whisper_context_default_params()
            contextParams.use_gpu = useGPU
            contextParams.flash_attn = false

            return modelURL.path.withCString { path in
                whisper_init_from_file_with_params(path, contextParams)
            }
        }

        let enableMetal = ProcessInfo.processInfo.environment["LOCAL_WHISPERER_ENABLE_METAL"] == "1"
        let loaded = enableMetal
            ? (loadContext(useGPU: true) ?? loadContext(useGPU: false))
            : loadContext(useGPU: false)
        guard let loaded else {
            throw LocalWhispererError.modelLoadFailed(modelURL.path)
        }

        context = loaded
        return loaded
    }
}

private final class LiveTranscriptionSession {
    private struct StateSnapshot {
        let chunks: [String]
        let committedEndSample: Int
        let failure: Error?
    }

    private let audioCapture: AudioCapture
    private let transcriber: WhisperTranscriber
    private let queue = DispatchQueue(label: "com.byrondaniels.duckwhisperer.live-transcription", qos: .userInitiated)
    private var generation = UUID()
    private var isRunning = false
    private var nextChunkStartSample = 0
    private var committedEndSample = 0
    private var chunks: [String] = []
    private var failure: Error?

    private let sampleRate = Int(WHISPER_SAMPLE_RATE)
    private var chunkSampleCount: Int { Int(Double(sampleRate) * 12.0) }
    private var minimumChunkSampleCount: Int { Int(Double(sampleRate) * 8.0) }
    private var boundarySearchSampleCount: Int { Int(Double(sampleRate) * 0.7) }
    private var boundaryWindowSampleCount: Int { Int(Double(sampleRate) * 0.16) }
    private var minimumLiveSampleCount: Int { Int(Double(sampleRate) * 12.0) }
    private var minimumTailSampleCount: Int { Int(Double(sampleRate) * 0.35) }

    init(audioCapture: AudioCapture, transcriber: WhisperTranscriber) {
        self.audioCapture = audioCapture
        self.transcriber = transcriber
    }

    func start() {
        let newGeneration = UUID()
        queue.async { [weak self] in
            guard let self else { return }
            generation = newGeneration
            isRunning = true
            nextChunkStartSample = 0
            committedEndSample = 0
            chunks.removeAll(keepingCapacity: true)
            failure = nil
            schedulePoll(for: newGeneration)
        }
    }

    func finish(with finalSamples: [Float]) throws -> String {
        let snapshot = queue.sync { () -> StateSnapshot in
            isRunning = false
            return StateSnapshot(
                chunks: chunks,
                committedEndSample: committedEndSample,
                failure: failure
            )
        }

        guard finalSamples.count >= minimumLiveSampleCount,
              snapshot.failure == nil,
              !snapshot.chunks.isEmpty
        else {
            return try transcriber.transcribe(samples: finalSamples)
        }

        do {
            var parts = snapshot.chunks
            let tailStart = min(snapshot.committedEndSample, finalSamples.count)
            if finalSamples.count - tailStart >= minimumTailSampleCount {
                let tailSamples = Array(finalSamples[tailStart..<finalSamples.count])
                let prompt = recentPrompt(from: parts)
                let tailTranscript = try transcriber.transcribe(
                    samples: tailSamples,
                    initialPrompt: prompt,
                    singleSegment: true
                )
                if !tailTranscript.isEmpty {
                    parts.append(tailTranscript)
                }
            }

            let transcript = normalizedTranscript(parts)
            return transcript.isEmpty ? try transcriber.transcribe(samples: finalSamples) : transcript
        } catch {
            return try transcriber.transcribe(samples: finalSamples)
        }
    }

    private func schedulePoll(for scheduledGeneration: UUID) {
        queue.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.processNextChunk(for: scheduledGeneration)
        }
    }

    private func processNextChunk(for scheduledGeneration: UUID) {
        guard isRunning,
              generation == scheduledGeneration,
              failure == nil
        else {
            return
        }

        let availableSampleCount = audioCapture.sampleCount()
        let minimumReadySampleCount = nextChunkStartSample + chunkSampleCount + boundarySearchSampleCount
        guard availableSampleCount >= minimumReadySampleCount else {
            schedulePoll(for: scheduledGeneration)
            return
        }

        let currentSamples = audioCapture.snapshotSamples()
        let chunkEndSample = quietChunkEnd(in: currentSamples, startSample: nextChunkStartSample)
        guard chunkEndSample > nextChunkStartSample else {
            schedulePoll(for: scheduledGeneration)
            return
        }

        let chunkSamples = Array(currentSamples[nextChunkStartSample..<chunkEndSample])
        let prompt = recentPrompt(from: chunks)

        do {
            let transcript = try transcriber.transcribe(
                samples: chunkSamples,
                initialPrompt: prompt,
                singleSegment: true
            )
            if !transcript.isEmpty {
                chunks.append(transcript)
            }
            committedEndSample = chunkEndSample
            nextChunkStartSample = chunkEndSample
        } catch {
            failure = error
            return
        }

        schedulePoll(for: scheduledGeneration)
    }

    private func quietChunkEnd(in samples: [Float], startSample: Int) -> Int {
        let targetEnd = min(samples.count, startSample + chunkSampleCount)
        let minimumEnd = min(samples.count, startSample + minimumChunkSampleCount)
        let searchStart = max(minimumEnd, targetEnd - boundarySearchSampleCount)
        let searchEnd = min(samples.count - boundaryWindowSampleCount, targetEnd + boundarySearchSampleCount)

        guard searchEnd > searchStart, boundaryWindowSampleCount > 0 else {
            return targetEnd
        }

        var bestEnd = targetEnd
        var bestScore = Float.greatestFiniteMagnitude
        let stride = max(1, boundaryWindowSampleCount / 4)
        var index = searchStart

        while index <= searchEnd {
            let score = averageAbsoluteAmplitude(in: samples, start: index, count: boundaryWindowSampleCount)
            if score < bestScore {
                bestScore = score
                bestEnd = index + boundaryWindowSampleCount / 2
            }
            index += stride
        }

        return max(minimumEnd, min(samples.count, bestEnd))
    }

    private func averageAbsoluteAmplitude(in samples: [Float], start: Int, count: Int) -> Float {
        guard count > 0, start >= 0, start + count <= samples.count else {
            return Float.greatestFiniteMagnitude
        }

        var total: Float = 0
        for index in start..<(start + count) {
            total += abs(samples[index])
        }
        return total / Float(count)
    }

    private func recentPrompt(from parts: [String]) -> String? {
        let text = normalizedTranscript(parts)
        guard !text.isEmpty else {
            return nil
        }

        if text.count <= 700 {
            return text
        }

        return String(text.suffix(700))
    }

    private func normalizedTranscript(_ parts: [String]) -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum LocalTranslator {
    private struct Runtime {
        let pythonURL: URL
        let scriptURL: URL
        let dataHomeURL: URL
        let cacheHomeURL: URL
    }

    static func translate(_ text: String, to outputLanguage: OutputLanguage) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let targetCode = outputLanguage.translationTargetCode else {
            return text
        }

        let runtime = try translationRuntime()
        let process = Process()
        process.executableURL = runtime.pythonURL
        process.arguments = [runtime.scriptURL.path, "--to", targetCode]

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

private enum DuckSpeech {
    private static let quacks = [
        "quack",
        "quaack",
        "quaaack",
        "quaaaack",
        "quaaaaack",
        "QUACK",
        "QUAAACK",
        "quack-quack",
        "quack quack",
        "quaack-quack",
        "quaaack quack",
        "QUACK-QUACK"
    ]

    static func render(_ text: String) -> String {
        let sentenceParts = splitIntoSentences(text)
        guard !sentenceParts.isEmpty else {
            return "Quack quack."
        }

        let rendered = sentenceParts.compactMap { part -> String? in
            let words = words(in: part.body)
            guard !words.isEmpty else {
                return nil
            }

            let quacks = words.enumerated().map { index, word in
                quack(for: word, at: index)
            }
            return sentenceCase(quacks.joined(separator: " ")) + part.terminator
        }

        return rendered.isEmpty ? "Quack quack." : rendered.joined(separator: " ")
    }

    private static func splitIntoSentences(_ text: String) -> [(body: String, terminator: String)] {
        var result: [(body: String, terminator: String)] = []
        var current = ""

        for character in text {
            if ".!?".contains(character) {
                let body = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    result.append((body: body, terminator: String(character)))
                }
                current.removeAll(keepingCapacity: true)
            } else if character.isNewline {
                let body = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !body.isEmpty {
                    result.append((body: body, terminator: "."))
                }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(character)
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append((body: tail, terminator: "."))
        }

        return result
    }

    private static func words(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func quack(for word: String, at index: Int) -> String {
        let value = word.unicodeScalars.reduce(index * 17) { partial, scalar in
            partial + Int(scalar.value)
        }
        return quacks[value % quacks.count]
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).uppercased() + String(text.dropFirst())
    }
}

private enum LocalWhispererError: LocalizedError {
    case audioReadFailed(String)
    case hotKeyFailed(OSStatus)
    case modelDownloadFailed(String)
    case modelLoadFailed(String)
    case modelMissing(String)
    case noRecording
    case recordingFailed
    case translationFailed(String)
    case translationInstallFailed(String)
    case translationModelMissing(String)
    case translationRuntimeMissing(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioReadFailed(let message):
            return message
        case .hotKeyFailed(let status):
            return "Could not register Option+Space. Another app may already own that shortcut. OSStatus \(status)."
        case .modelDownloadFailed(let message):
            return "Model download failed: \(message)"
        case .modelLoadFailed(let path):
            return "Could not load the Whisper model at \(path)."
        case .modelMissing(let path):
            return "Missing Whisper model at \(path)."
        case .noRecording:
            return "No active recording."
        case .recordingFailed:
            return "The microphone did not start recording."
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .translationInstallFailed(let message):
            return "Translation install failed: \(message)"
        case .translationModelMissing(let path):
            return "Missing local translation models at \(path). Run scripts/setup_local_translation.sh."
        case .translationRuntimeMissing(let path):
            return "Missing local translation runtime at \(path). Run scripts/setup_local_translation.sh."
        case .transcriptionFailed(let message):
            return message
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let modelMenu = NSMenu()
    private let outputMenu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
    private let copyLastMenuItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript), keyEquivalent: "")
    private let preserveCapitalizationMenuItem = NSMenuItem(title: "Preserve Capitalization", action: #selector(togglePreserveCapitalization), keyEquivalent: "")
    private let hotKeyController = HotKeyController()
    private let audioCapture = AudioCapture()
    private let recordingOverlay = RecordingOverlayController()
    private let transcriptionResult = TranscriptionResultController()
    private lazy var transcriber = WhisperTranscriber(modelURL: modelURL)
    private lazy var modelExplorer = ModelExplorerController(
        currentModel: selectedModel,
        onUseModel: { [weak self] choice in
            self?.useModel(choice)
        },
        onModelsChanged: { [weak self] in
            self?.handleModelsChanged()
        }
    )
    private var state: AppState = .ready
    private var lastTranscript = ""
    private var liveTranscriptionSession: LiveTranscriptionSession?
    private var pasteTarget: PasteTarget?

    private var selectedModel: ModelChoice {
        let choice = ModelChoice.choice(for: UserDefaults.standard.string(forKey: selectedModelIDKey))
        return ModelStore.isInstalled(choice) ? choice : ModelChoice.defaultChoice
    }

    private var selectedOutputLanguage: OutputLanguage {
        OutputLanguage.choice(for: UserDefaults.standard.string(forKey: selectedOutputLanguageIDKey))
    }

    private var preserveCapitalization: Bool {
        if UserDefaults.standard.object(forKey: preserveCapitalizationKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: preserveCapitalizationKey)
    }

    private var modelURL: URL {
        ModelStore.installedURL(for: selectedModel)
            ?? ModelStore.installedURL(for: ModelChoice.defaultChoice)
            ?? ModelStore.bundledURL(for: ModelChoice.defaultChoice)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installApplicationIcon()
        AppLog.write("launched \(buildMarker); axTrusted=\(AXIsProcessTrusted())")

        setupMenu()
        requestMicrophoneAccess()

        let hotKeyStatus = hotKeyController.register { [weak self] in
            self?.toggleRecording()
        }

        if hotKeyStatus == noErr {
            if ModelStore.isInstalled(selectedModel) {
                setState(.ready)
                preloadModel()
            } else {
                setState(.error("Download Small English in Model Explorer before recording."))
                showModelExplorer()
            }
        } else {
            setState(.error(LocalWhispererError.hotKeyFailed(hotKeyStatus).localizedDescription))
        }

        if CommandLine.arguments.contains("--open-model-explorer") {
            showModelExplorer()
        }

        if let debugPasteText {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                self.pasteTarget = PasteTargetDetector.captureFocusedEditableTarget()
                self.copyToClipboard(debugPasteText)
                self.deliverTranscript(debugPasteText)
            }
        }
    }

    private func preloadModel() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try self?.transcriber.preload()
            } catch {
                DispatchQueue.main.async {
                    self?.setState(.error(error.localizedDescription))
                }
            }
        }
    }

    private func installApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "DuckWhisperer", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }
        NSApp.applicationIconImage = icon
    }

    private func setupMenu() {
        statusItem.button?.title = ""
        statusItem.button?.image = DuckIcon.menuBarImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = appDisplayName
        statusMenuItem.isEnabled = false
        toggleMenuItem.target = self
        copyLastMenuItem.target = self
        copyLastMenuItem.isEnabled = false
        preserveCapitalizationMenuItem.target = self

        let openMicSettings = NSMenuItem(
            title: "Open Microphone Settings",
            action: #selector(openMicrophoneSettings),
            keyEquivalent: ""
        )
        openMicSettings.target = self

        let openAccessibilitySettings = NSMenuItem(
            title: "Open Accessibility Settings for Auto-Paste",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAccessibilitySettings.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(copyLastMenuItem)
        menu.addItem(outputMenuItem())
        menu.addItem(preserveCapitalizationMenuItem)
        let topLevelModelExplorer = NSMenuItem(
            title: "Open Model Explorer...",
            action: #selector(openModelExplorer(_:)),
            keyEquivalent: ""
        )
        topLevelModelExplorer.target = self
        menu.addItem(topLevelModelExplorer)
        menu.addItem(modelMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(openMicSettings)
        menu.addItem(openAccessibilitySettings)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        rebuildPreserveCapitalizationMenuItem()
        rebuildOutputMenu()
        rebuildModelMenu()
    }

    private func outputMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Output Language", action: nil, keyEquivalent: "")
        item.submenu = outputMenu
        return item
    }

    private func modelMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        item.submenu = modelMenu
        return item
    }

    private func rebuildOutputMenu() {
        outputMenu.removeAllItems()
        let current = selectedOutputLanguage

        for language in OutputLanguage.all {
            let item = NSMenuItem(title: language.title, action: #selector(selectOutputLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.id
            item.state = language == current ? .on : .off
            outputMenu.addItem(item)
        }
    }

    private func rebuildPreserveCapitalizationMenuItem() {
        preserveCapitalizationMenuItem.state = preserveCapitalization ? .on : .off
    }

    private func rebuildModelMenu() {
        modelMenu.removeAllItems()
        let current = selectedModel

        let explorerItem = NSMenuItem(title: "Open Model Explorer...", action: #selector(openModelExplorer(_:)), keyEquivalent: "")
        explorerItem.target = self
        modelMenu.addItem(explorerItem)
        modelMenu.addItem(NSMenuItem.separator())

        for choice in ModelChoice.all {
            let exists = ModelStore.isInstalled(choice)
            let title = exists
                ? "\(choice.title) - \(choice.detail)"
                : "\(choice.title) - not installed"
            let item = NSMenuItem(
                title: title,
                action: exists ? #selector(selectModel(_:)) : #selector(openModelExplorer(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = choice.id
            item.state = choice == current ? .on : .off
            modelMenu.addItem(item)
        }

        modelMenu.addItem(NSMenuItem.separator())
        let openInstalledModels = NSMenuItem(title: "Open Installed Models Folder", action: #selector(openInstalledModelsFolder), keyEquivalent: "")
        openInstalledModels.target = self
        modelMenu.addItem(openInstalledModels)

        let openBundledModels = NSMenuItem(title: "Open Bundled Models Folder", action: #selector(openBundledModelsFolder), keyEquivalent: "")
        openBundledModels.target = self
        modelMenu.addItem(openBundledModels)
    }

    private func setState(_ newState: AppState) {
        state = newState
        statusItem.button?.title = ""
        statusItem.button?.image = DuckIcon.menuBarImage()
        statusItem.button?.toolTip = "\(appDisplayName): \(newState.statusText)"
        let formattingText = preserveCapitalization ? "Caps On" : "Caps Off"
        statusMenuItem.title = "\(newState.statusText) - \(selectedModel.title) -> \(selectedOutputLanguage.title) - \(formattingText)"

        switch newState {
        case .ready, .error:
            recordingOverlay.hide()
            toggleMenuItem.title = "Start Recording"
            toggleMenuItem.isEnabled = true
        case .recording:
            recordingOverlay.show()
            toggleMenuItem.title = "Stop and Paste"
            toggleMenuItem.isEnabled = true
        case .transcribing:
            recordingOverlay.show()
            toggleMenuItem.title = "Transcribing..."
            toggleMenuItem.isEnabled = false
        }

        copyLastMenuItem.isEnabled = !lastTranscript.isEmpty
        rebuildPreserveCapitalizationMenuItem()
    }

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    private func requestAccessibilityAccessIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        AppLog.write("requested Accessibility permission prompt")
    }

    private func logAccessibilityStateForRecording() {
        AppLog.write("recording start; axTrusted=\(AXIsProcessTrusted())")
    }

    @objc private func toggleRecordingFromMenu() {
        toggleRecording()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        useModel(ModelChoice.choice(for: id))
    }

    private func useModel(_ choice: ModelChoice) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let modelURL = ModelStore.installedURL(for: choice) else {
            showModelExplorer()
            return
        }

        UserDefaults.standard.set(choice.id, forKey: selectedModelIDKey)
        transcriber.setModelURL(modelURL)
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel)
        setState(.ready)
        preloadModel()
    }

    private func handleModelsChanged() {
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel)
        if ModelStore.isInstalled(selectedModel) {
            setState(.ready)
            preloadModel()
        } else {
            setState(state)
        }
    }

    @objc private func selectOutputLanguage(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        let language = OutputLanguage.choice(for: id)
        UserDefaults.standard.set(language.id, forKey: selectedOutputLanguageIDKey)
        rebuildOutputMenu()
        setState(.ready)
    }

    @objc private func togglePreserveCapitalization() {
        UserDefaults.standard.set(!preserveCapitalization, forKey: preserveCapitalizationKey)
        rebuildPreserveCapitalizationMenuItem()
        setState(state)
    }

    private func toggleRecording() {
        switch state {
        case .ready, .error:
            startRecording()
        case .recording:
            stopTranscribeAndPaste()
        case .transcribing:
            NSSound.beep()
        }
    }

    private func startRecording() {
        guard ModelStore.isInstalled(selectedModel) else {
            setState(.error("Download a speech model in Model Explorer before recording."))
            showModelExplorer()
            NSSound.beep()
            return
        }

        logAccessibilityStateForRecording()

        do {
            pasteTarget = PasteTargetDetector.captureFocusedEditableTarget()
            try audioCapture.start()
            let session = LiveTranscriptionSession(audioCapture: audioCapture, transcriber: transcriber)
            liveTranscriptionSession = session
            session.start()
            setState(.recording)
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
        }
    }

    private func stopTranscribeAndPaste() {
        let samples: [Float]
        let liveSession = liveTranscriptionSession
        liveTranscriptionSession = nil

        do {
            samples = try audioCapture.stop()
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
            return
        }

        setState(.transcribing)
        let outputLanguage = selectedOutputLanguage
        let shouldPreserveCapitalization = preserveCapitalization

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let startedAt = Date()
                let transcript = try liveSession?.finish(with: samples)
                    ?? self.transcriber.transcribe(samples: samples)
                let translatedOutput = try LocalTranslator.translate(transcript, to: outputLanguage)
                let languageOutput = self.applyLanguageOutput(to: translatedOutput, outputLanguage: outputLanguage)
                let output = self.applyOutputFormatting(
                    to: languageOutput,
                    preserveCapitalization: shouldPreserveCapitalization
                )
                let elapsed = Date().timeIntervalSince(startedAt)

                DispatchQueue.main.async {
                    AppLog.write(String(format: "transcribed %.2fs of audio in %.2fs", Double(samples.count) / Double(WHISPER_SAMPLE_RATE), elapsed))
                    self.lastTranscript = output
                    self.copyToClipboard(output)
                    self.deliverTranscript(output)
                }
            } catch {
                DispatchQueue.main.async {
                    self.setState(.error(error.localizedDescription))
                    NSSound.beep()
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func applyLanguageOutput(to text: String, outputLanguage: OutputLanguage) -> String {
        switch outputLanguage.id {
        case "duck":
            return DuckSpeech.render(text)
        default:
            return text
        }
    }

    private func applyOutputFormatting(to text: String, preserveCapitalization: Bool) -> String {
        guard !preserveCapitalization else {
            return text
        }
        return text.localizedLowercase
    }

    private func deliverTranscript(_ output: String) {
        let target = pasteTarget
        pasteTarget = nil

        guard AXIsProcessTrusted() else {
            AppLog.write("delivery fallback; Accessibility not trusted, transcript copied and transcript window shown")
            transcriptionResult.show(text: output)
            setState(.ready)
            return
        }

        let finish: (_ allowFocusedCheckBypass: Bool) -> Void = { [weak self] allowFocusedCheckBypass in
            guard let self else { return }
            if !self.pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: allowFocusedCheckBypass) {
                self.transcriptionResult.show(text: output)
            }
            self.setState(.ready)
        }

        guard let target
        else {
            AppLog.write("delivery target missing; attempting focused paste")
            finish(false)
            return
        }

        AppLog.write("delivery start target=\(targetDescription(target)) synthetic=\(shouldUseSyntheticTyping(for: target))")

        if target.element == nil {
            AppLog.write("blind paste path for AX-invisible target; axTrusted=\(AXIsProcessTrusted()) app=\(target.application?.localizedName ?? "nil")")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.setState(.ready)
                    return
                }
                finish(true)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
        if let application = target.application, !application.isTerminated {
            application.activate(options: [.activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let restoredFocus = PasteTargetDetector.focusCapturedTarget(target)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.setState(.ready)
                    return
                }
                if PasteTargetDetector.insertTextDirectly(output, into: target) {
                    self.setState(.ready)
                    return
                }
                finish(restoredFocus || target.application != nil)
            }
        }
    }

    private func shouldUseSyntheticTyping(for target: PasteTarget) -> Bool {
        let appName = target.application?.localizedName?.lowercased() ?? ""
        return appName.contains("codex")
    }

    private func targetDescription(_ target: PasteTarget) -> String {
        let appName = target.application?.localizedName ?? "nil"
        let bundleID = target.application?.bundleIdentifier ?? "nil"
        let pidText = target.pid.map { String($0) } ?? "nil"
        return "app=\(appName) bundle=\(bundleID) pid=\(pidText) element=\(target.element == nil ? "nil" : "editable")"
    }

    private func typeTextWithKeyboard(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            AppLog.write("synthetic typing skipped; Accessibility is not trusted")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            AppLog.write("synthetic typing skipped; could not create event source")
            return false
        }

        let units = Array(text.utf16)
        for unit in units {
            var character = unit
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                AppLog.write("synthetic typing failed; could not create key event")
                return false
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(700)
        }

        AppLog.write("synthetic typing posted \(units.count) UTF-16 units")
        return true
    }

    private func pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: Bool = false) -> Bool {
        guard AXIsProcessTrusted() else {
            AppLog.write("paste skipped; Accessibility is not trusted")
            return false
        }

        guard allowWithoutFocusedCheck || PasteTargetDetector.canAttemptPasteIntoFocusedTarget() else {
            AppLog.write("paste skipped; no focused editable target")
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        AppLog.write("paste command posted")
        return true
    }

    @objc private func copyLastTranscript() {
        guard !lastTranscript.isEmpty else {
            return
        }
        copyToClipboard(lastTranscript)
    }

    @objc private func openMicrophoneSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityAccessIfNeeded()
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func openModelExplorer(_ sender: Any?) {
        AppLog.write("open model explorer action fired from \(String(describing: type(of: sender as Any)))")
        showModelExplorer()
    }

    private func showModelExplorer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            AppLog.write("presenting model explorer after menu close")
            self.modelExplorer.show(currentModel: self.selectedModel)
        }
    }

    @objc private func openInstalledModelsFolder() {
        do {
            try FileManager.default.createDirectory(at: ModelStore.userModelsURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(ModelStore.userModelsURL)
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
        }
    }

    @objc private func openBundledModelsFolder() {
        NSWorkspace.shared.open(ModelStore.bundledModelsURL)
    }

    private func openSettings(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private func runSmokeTranscriptionIfRequested() {
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

runSmokeTranscriptionIfRequested()

private func captureDebugPasteTextIfRequested() {
    let arguments = CommandLine.arguments
    guard let flagIndex = arguments.firstIndex(of: "--debug-paste-text"),
          arguments.indices.contains(flagIndex + 1)
    else {
        return
    }
    debugPasteText = arguments[flagIndex + 1]
}

captureDebugPasteTextIfRequested()

private let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()
