import SwiftUI
import Translation

private enum PondRuntime {
    static let environment = ProcessInfo.processInfo.environment
    static let outputURL = URL(
        fileURLWithPath: environment["DUCKWHISPERER_POND_OUTPUT"]
            ?? "/tmp/duckwhisperer-translation-pond/results.jsonl"
    )
}

@available(macOS 26.0, *)
private struct PondPair: Identifiable, Equatable {
    let id: String
    let title: String
    let targetCode: String

    static let all: [PondPair] = [
        PondPair(id: "en-nl", title: "English -> Dutch", targetCode: "nl"),
        PondPair(id: "en-fr", title: "English -> French", targetCode: "fr")
    ]
}

@available(macOS 26.0, *)
private struct PondRow: Identifiable, Equatable {
    let id: String
    let pair: PondPair
    var status: String
    var detail: String
}

@main
private struct TranslationPondApp: App {
    var body: some Scene {
        WindowGroup("Translation Pond") {
            if #available(macOS 26.0, *) {
                PondView()
                    .frame(width: 460, height: 400)
            } else {
                VStack(spacing: 10) {
                    Text("Translation Pond")
                        .font(.title2.bold())
                    Text("Apple Translation asset prep requires macOS 26 or newer.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(width: 420, height: 220)
            }
        }
    }
}

@available(macOS 26.0, *)
private struct PondView: View {
    @State private var rows = PondPair.all.map {
        PondRow(id: $0.id, pair: $0, status: "Checking", detail: "Checking Apple local assets...")
    }
    @State private var configuration: TranslationSession.Configuration?
    @State private var activePair: PondPair?
    @State private var pendingPairs: [PondPair] = []
    @State private var isPreparing = false
    @State private var logLines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Translation Pond")
                .font(.title2.bold())
            Text("Installs or verifies Apple's local translation assets for DuckWhisperer. Apple may ask for permission if a language pair needs a download.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color(for: row.status))
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(row.pair.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(row.status)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(row.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 10) {
                Button(isPreparing ? "Preparing..." : "Install Local Assets") {
                    startPreparing()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isPreparing)

                Button("Refresh") {
                    Task { await refreshAvailability() }
                }
                .disabled(isPreparing)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .task {
            resetOutput()
            await refreshAvailability()
            if PondRuntime.environment["DUCKWHISPERER_POND_AUTO_START"] == "1" {
                await MainActor.run {
                    startPreparing()
                }
            }
        }
        .translationTask(configuration) { session in
            await prepareActivePair(with: session)
        }
    }

    private func color(for status: String) -> Color {
        switch status {
        case "Ready":
            return .green
        case "Checking", "Preparing":
            return .yellow
        case "Failed", "Unsupported":
            return .red
        default:
            return .secondary
        }
    }

    @MainActor
    private func startPreparing() {
        guard !isPreparing else {
            return
        }
        isPreparing = true
        pendingPairs = PondPair.all
        logLines = []
        append("Starting Apple Translation asset prep...")
        prepareNextPair()
    }

    @MainActor
    private func prepareNextPair() {
        guard !pendingPairs.isEmpty else {
            activePair = nil
            configuration = nil
            isPreparing = false
            append("Done.")
            Task { await refreshAvailability() }
            if PondRuntime.environment["DUCKWHISPERER_POND_AUTO_EXIT"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NSApp.terminate(nil)
                }
            }
            return
        }

        let pair = pendingPairs.removeFirst()
        activePair = pair
        update(pair, status: "Preparing", detail: "Waiting for Apple Translation to prepare this pair...")
        append("Preparing \(pair.title)...")

        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: pair.targetCode)
        if #available(macOS 26.4, *) {
            configuration = TranslationSession.Configuration(
                source: source,
                target: target,
                preferredStrategy: .highFidelity
            )
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private func prepareActivePair(with session: TranslationSession) async {
        guard isPreparing, let pair = activePair else {
            return
        }

        do {
            let started = Date()
            try await session.prepareTranslation()
            let response = try await session.translate("Please confirm that the presentation is ready for the client.")
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            await MainActor.run {
                update(pair, status: "Ready", detail: "Prepared and verified in \(elapsedMs) ms.")
                append("\(pair.title) ready: \(response.targetText)")
                writeJSONLine([
                    "pair": pair.id,
                    "status": "ready",
                    "elapsedMs": String(elapsedMs),
                    "verification": response.targetText
                ])
                prepareNextPair()
            }
        } catch {
            await MainActor.run {
                update(pair, status: "Failed", detail: error.localizedDescription)
                append("\(pair.title) failed: \(error.localizedDescription)")
                writeJSONLine([
                    "pair": pair.id,
                    "status": "failed",
                    "error": error.localizedDescription
                ])
                prepareNextPair()
            }
        }
    }

    private func refreshAvailability() async {
        for pair in PondPair.all {
            await MainActor.run {
                update(pair, status: "Checking", detail: "Checking Apple local asset availability...")
            }
            let status = await availabilityStatus(for: pair)
            await MainActor.run {
                update(pair, status: status.title, detail: status.detail)
            }
        }
    }

    private func availabilityStatus(for pair: PondPair) async -> (title: String, detail: String) {
        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: pair.targetCode)
        let availability: LanguageAvailability
        if #available(macOS 26.4, *) {
            availability = LanguageAvailability(preferredStrategy: .highFidelity)
        } else {
            availability = LanguageAvailability()
        }
        let status = await availability.status(from: source, to: target)

        switch status {
        case .installed:
            return ("Ready", "Apple reports this language pair is installed and ready.")
        case .supported:
            return ("Needed", "Apple supports this pair, but local assets are not ready yet.")
        case .unsupported:
            return ("Unsupported", "Apple does not support this language pair on this Mac.")
        @unknown default:
            return ("Unknown", "Apple returned an unknown availability state.")
        }
    }

    @MainActor
    private func update(_ pair: PondPair, status: String, detail: String) {
        guard let index = rows.firstIndex(where: { $0.pair == pair }) else {
            return
        }
        rows[index].status = status
        rows[index].detail = detail
    }

    @MainActor
    private func append(_ line: String) {
        logLines.append(line)
    }

    private func resetOutput() {
        try? FileManager.default.createDirectory(
            at: PondRuntime.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? "".write(to: PondRuntime.outputURL, atomically: true, encoding: .utf8)
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
           let handle = try? FileHandle(forWritingTo: PondRuntime.outputURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}
