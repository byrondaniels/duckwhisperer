import AppKit
import SwiftUI
import Translation

final class AppleTranslationAssetsController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        guard #available(macOS 26.0, *) else {
            let alert = NSAlert()
            alert.messageText = "Apple Translation needs macOS 26 or newer"
            alert.informativeText = "Dutch and French system translation require Apple's Translation framework."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let window: NSWindow
        if let existingWindow = self.window {
            window = existingWindow
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 390),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Translation Pond"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 390, height: 320)
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentViewController = NSHostingController(rootView: AppleTranslationAssetsView())
            window.delegate = self
            self.window = window
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@available(macOS 26.0, *)
private struct AppleTranslationAssetPair: Identifiable, Equatable {
    let id: String
    let title: String
    let targetCode: String

    static let supported: [AppleTranslationAssetPair] = [
        AppleTranslationAssetPair(id: "en-nl", title: "English -> Dutch", targetCode: "nl"),
        AppleTranslationAssetPair(id: "en-fr", title: "English -> French", targetCode: "fr")
    ]
}

@available(macOS 26.0, *)
private struct AppleTranslationAssetRow: Identifiable, Equatable {
    let id: String
    let pair: AppleTranslationAssetPair
    var status: String
    var detail: String
}

@available(macOS 26.0, *)
private struct AppleTranslationAssetsView: View {
    @State private var rows = AppleTranslationAssetPair.supported.map {
        AppleTranslationAssetRow(id: $0.id, pair: $0, status: "Checking", detail: "Looking for Apple local assets...")
    }
    @State private var configuration: TranslationSession.Configuration?
    @State private var activePair: AppleTranslationAssetPair?
    @State private var pendingPairs: [AppleTranslationAssetPair] = []
    @State private var isPreparing = false
    @State private var logLines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Translation Pond")
                .font(.title2.bold())

            Text("Prepares Apple's local translation assets for DuckWhisperer. Dutch and French use this Apple path directly; legacy packs stay manual test options.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    assetRow(row)
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
            await refreshAvailability()
        }
        .translationTask(configuration) { session in
            await prepareActivePair(with: session)
        }
    }

    private func assetRow(_ row: AppleTranslationAssetRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(statusColor(row.status))
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

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Ready":
            return .green
        case "Preparing", "Checking":
            return .yellow
        case "Unsupported", "Failed":
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
        pendingPairs = AppleTranslationAssetPair.supported
        logLines = []
        append("Starting Apple asset preparation...")
        prepareNextPair()
    }

    @MainActor
    private func prepareNextPair() {
        guard !pendingPairs.isEmpty else {
            activePair = nil
            configuration = nil
            isPreparing = false
            append("Done. Refreshing availability...")
            Task { await refreshAvailability() }
            return
        }

        let pair = pendingPairs.removeFirst()
        activePair = pair
        update(pair, status: "Preparing", detail: "Apple may ask permission to download local assets.")
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
            try await session.prepareTranslation()
            let response = try await session.translate("Please confirm that the presentation is ready for the client.")
            await MainActor.run {
                update(pair, status: "Ready", detail: "Prepared and verified: \(response.targetText)")
                append("\(pair.title) ready.")
                prepareNextPair()
            }
        } catch {
            await MainActor.run {
                update(pair, status: "Failed", detail: error.localizedDescription)
                append("\(pair.title) failed: \(error.localizedDescription)")
                prepareNextPair()
            }
        }
    }

    private func refreshAvailability() async {
        await MainActor.run {
            for pair in AppleTranslationAssetPair.supported {
                update(pair, status: "Checking", detail: "Checking Apple local asset availability...")
            }
        }

        for pair in AppleTranslationAssetPair.supported {
            let status = await availabilityStatus(for: pair)
            await MainActor.run {
                update(pair, status: status.title, detail: status.detail)
            }
        }
    }

    private func availabilityStatus(for pair: AppleTranslationAssetPair) async -> (title: String, detail: String) {
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
    private func update(_ pair: AppleTranslationAssetPair, status: String, detail: String) {
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
}
