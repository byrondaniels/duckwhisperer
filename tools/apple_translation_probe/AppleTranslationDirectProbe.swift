import AppKit
import Darwin
import Foundation
import Translation

private let outputURL = URL(fileURLWithPath: "/tmp/duckwhisperer-apple-translation-probe/direct.jsonl")

final class AppleTranslationDirectProbe: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await run()
            NSApp.terminate(nil)
            exit(0)
        }
    }

    private func run() async {
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? "".write(to: outputURL, atomically: true, encoding: .utf8)

        guard #available(macOS 26.0, *) else {
            write(["error": "TranslationSession installedSource initializer unavailable"])
            return
        }

        let cases = [
            ("nl", "The call ran long because the vendor kept circling back to the same issue."),
            ("nl", "I'm going to duck out early today, but I'll review the contract tonight."),
            ("fr", "Can you move the standup to tomorrow morning and let the Amsterdam team know?")
        ]

        for (targetCode, text) in cases {
            let startedAt = Date()
            let source = Locale.Language(identifier: "en")
            let target = Locale.Language(identifier: targetCode)
            let session: TranslationSession
            if #available(macOS 26.4, *) {
                session = TranslationSession(
                    installedSource: source,
                    target: target,
                    preferredStrategy: .highFidelity
                )
            } else {
                session = TranslationSession(installedSource: source, target: target)
            }

            do {
                let response = try await session.translate(text)
                write([
                    "target": targetCode,
                    "elapsedMs": String(Int(Date().timeIntervalSince(startedAt) * 1000)),
                    "source": text,
                    "translation": response.targetText
                ])
            } catch {
                write([
                    "target": targetCode,
                    "source": text,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func write(_ fields: [String: String]) {
        let escaped = fields.mapValues { value in
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
        }
        let body = escaped
            .sorted { $0.key < $1.key }
            .map { "\"\($0.key)\":\"\($0.value)\"" }
            .joined(separator: ",")
        let line = "{\(body)}\n"
        if let data = line.data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: outputURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

NSApplication.shared.setActivationPolicy(.accessory)
let delegate = AppleTranslationDirectProbe()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
