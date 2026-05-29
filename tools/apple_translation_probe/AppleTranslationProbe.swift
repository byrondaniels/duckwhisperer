import SwiftUI
import Translation

private let processEnvironment = ProcessInfo.processInfo.environment
private let outputURL = URL(
    fileURLWithPath: processEnvironment["APPLE_TRANSLATION_PROBE_OUTPUT"]
        ?? "/tmp/duckwhisperer-apple-translation-probe/results.jsonl"
)

private enum ProbeStrategy: String {
    case highFidelity
    case lowLatency
}

private struct ProbeGroup: Identifiable {
    let id: String
    let targetCode: String
    let targetName: String
    let strategy: ProbeStrategy
}

private struct SourceCase {
    let id: String
    let text: String
}

private let sourceCases: [SourceCase] = [
    SourceCase(
        id: "business-deck-raw",
        text: "I need you to send the deck to the client before lunch. The current version is rough, so please clean up the wording without changing the numbers."
    ),
    SourceCase(
        id: "business-deck-explicit",
        text: "I need you to send the presentation deck to the client before lunch. The current draft needs polishing, so please improve the wording without changing the numbers."
    ),
    SourceCase(
        id: "business-context-prefix",
        text: "Business presentation context: send the deck to the client before lunch and polish the wording without changing any numbers."
    ),
    SourceCase(
        id: "circling-back",
        text: "The call ran long because the vendor kept circling back to the same issue."
    ),
    SourceCase(
        id: "duck-out",
        text: "I'm going to duck out early today, but I'll review the contract tonight."
    ),
    SourceCase(
        id: "standup",
        text: "Can you move the standup to tomorrow morning and let the Amsterdam team know?"
    ),
    SourceCase(
        id: "redlines",
        text: "Please follow up with legal and make sure the redlines are still tracked before we send the agreement."
    ),
    SourceCase(
        id: "table-it",
        text: "Let's table that issue until next week so we can focus on the launch plan today."
    )
]

private let allProbeGroups: [ProbeGroup] = [
    ProbeGroup(id: "highFidelity-nl", targetCode: "nl", targetName: "Dutch", strategy: .highFidelity),
    ProbeGroup(id: "highFidelity-fr", targetCode: "fr", targetName: "French", strategy: .highFidelity),
    ProbeGroup(id: "lowLatency-nl", targetCode: "nl", targetName: "Dutch", strategy: .lowLatency),
    ProbeGroup(id: "lowLatency-fr", targetCode: "fr", targetName: "French", strategy: .lowLatency)
]

private let probeGroups: [ProbeGroup] = {
    allProbeGroups.filter { group in
        let targetMatches = processEnvironment["APPLE_TRANSLATION_PROBE_TARGET"].map { $0 == group.targetCode } ?? true
        let strategyMatches = processEnvironment["APPLE_TRANSLATION_PROBE_STRATEGY"].map { $0 == group.strategy.rawValue } ?? true
        return targetMatches && strategyMatches
    }
}()

@main
struct AppleTranslationProbeApp: App {
    var body: some Scene {
        WindowGroup("Apple Translation Probe") {
            ProbeView()
                .frame(width: 760, height: 520)
        }
    }
}

private struct ProbeView: View {
    @State private var selectedGroupIndex = 0
    @State private var configuration: TranslationSession.Configuration?
    @State private var lines: [String] = []
    @State private var isRunning = false

    private var currentGroup: ProbeGroup? {
        guard probeGroups.indices.contains(selectedGroupIndex) else {
            return nil
        }
        return probeGroups[selectedGroupIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Translation Probe")
                .font(.title.bold())
            Text("Runs English -> Dutch/French through Apple's Translation framework from a real SwiftUI app.")
                .foregroundStyle(.secondary)

            HStack {
                Button(isRunning ? "Running..." : "Run All") {
                    start()
                }
                .disabled(isRunning)

                Button("Reveal Results") {
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .onAppear {
            start()
        }
        .translationTask(configuration) { session in
            await runCurrentGroup(with: session)
        }
    }

    private func start() {
        guard !isRunning else {
            return
        }

        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if processEnvironment["APPLE_TRANSLATION_PROBE_APPEND"] != "1" {
            try? "".write(to: outputURL, atomically: true, encoding: .utf8)
        }

        lines = []
        selectedGroupIndex = 0
        isRunning = true
        append("Starting Apple Translation probe...")
        configureCurrentGroup()
    }

    private func configureCurrentGroup() {
        guard let group = currentGroup else {
            append("DONE")
            isRunning = false
            configuration = nil
            if processEnvironment["APPLE_TRANSLATION_PROBE_AUTO_EXIT"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
            return
        }

        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: group.targetCode)
        append("Preparing \(group.id) -> \(group.targetName)")

        if #available(macOS 26.4, *) {
            let strategy: TranslationSession.Strategy = group.strategy == .lowLatency
                ? .lowLatency
                : .highFidelity
            configuration = TranslationSession.Configuration(
                source: source,
                target: target,
                preferredStrategy: strategy
            )
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private func runCurrentGroup(with session: TranslationSession) async {
        guard isRunning, let group = currentGroup else {
            return
        }

        let availability = LanguageAvailability()
        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: group.targetCode)
        let status = await availability.status(from: source, to: target)

        await MainActor.run {
            append("Availability for en -> \(group.targetCode): \(String(describing: status))")
        }

        do {
            try await session.prepareTranslation()
        } catch {
            await MainActor.run {
                append("PREPARE ERROR \(group.id): \(error.localizedDescription)")
                writeJSONLine([
                    "group": group.id,
                    "target": group.targetCode,
                    "strategy": group.strategy.rawValue,
                    "availability": String(describing: status),
                    "error": error.localizedDescription
                ])
                advanceGroup()
            }
            return
        }

        for sourceCase in sourceCases {
            let startedAt = Date()
            do {
                let response = try await session.translate(sourceCase.text)
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                await MainActor.run {
                    append("IN  \(sourceCase.text)")
                    append("OUT \(response.targetText)")
                    append("Took \(elapsedMs) ms")
                    writeJSONLine([
                        "id": "\(group.id)-\(sourceCase.id)",
                        "group": group.id,
                        "target": group.targetCode,
                        "strategy": group.strategy.rawValue,
                        "availability": String(describing: status),
                        "elapsedMs": String(elapsedMs),
                        "source": sourceCase.text,
                        "translation": response.targetText
                    ])
                }
            } catch {
                await MainActor.run {
                    append("ERROR \(group.id)-\(sourceCase.id): \(error.localizedDescription)")
                    writeJSONLine([
                        "id": "\(group.id)-\(sourceCase.id)",
                        "group": group.id,
                        "target": group.targetCode,
                        "strategy": group.strategy.rawValue,
                        "availability": String(describing: status),
                        "error": error.localizedDescription,
                        "source": sourceCase.text
                    ])
                }
            }
        }

        await MainActor.run {
            advanceGroup()
        }
    }

    @MainActor
    private func advanceGroup() {
        selectedGroupIndex += 1
        configureCurrentGroup()
    }

    @MainActor
    private func append(_ line: String) {
        lines.append(line)
    }

    private func writeJSONLine(_ fields: [String: String]) {
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
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}
