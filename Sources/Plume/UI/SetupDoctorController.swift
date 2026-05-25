import AppKit
import AVFoundation

final class SetupDoctorController: NSObject {
    private let window: NSWindow
    private let stackView = NSStackView()
    private let progressLabel = NSTextField(labelWithString: "")
    private let onOpenMicrophone: () -> Void
    private let onOpenAccessibility: () -> Void
    private let onOpenModelExplorer: () -> Void
    private let onOpenTryIt: () -> Void
    private let onExportSupportBundle: () -> Void

    init(
        onOpenMicrophone: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onOpenModelExplorer: @escaping () -> Void,
        onOpenTryIt: @escaping () -> Void,
        onExportSupportBundle: @escaping () -> Void
    ) {
        self.onOpenMicrophone = onOpenMicrophone
        self.onOpenAccessibility = onOpenAccessibility
        self.onOpenModelExplorer = onOpenModelExplorer
        self.onOpenTryIt = onOpenTryIt
        self.onExportSupportBundle = onExportSupportBundle
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "Finish Setup"
        window.isReleasedWhenClosed = false
        buildWindow()
    }

    func show() {
        rebuild()
        if !window.isVisible {
            window.center()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let title = NSTextField(labelWithString: "Finish Setup")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .boldSystemFont(ofSize: 22)

        let subtitle = NSTextField(labelWithString: "Make sure Plume can listen, paste your words, and run privately on this Mac.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor = .secondaryLabelColor

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded

        let tryButton = NSButton(title: "Try It Here", target: self, action: #selector(openTryIt))
        tryButton.translatesAutoresizingMaskIntoConstraints = false
        tryButton.bezelStyle = .rounded

        let supportButton = NSButton(title: "Export Support Bundle", target: self, action: #selector(exportSupportBundle))
        supportButton.translatesAutoresizingMaskIntoConstraints = false
        supportButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(progressLabel)
        contentView.addSubview(stackView)
        contentView.addSubview(tryButton)
        contentView.addSubview(supportButton)
        contentView.addSubview(refreshButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            progressLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            progressLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),

            stackView.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 14),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: refreshButton.topAnchor, constant: -16),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),

            refreshButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            refreshButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            tryButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            tryButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            supportButton.leadingAnchor.constraint(equalTo: tryButton.trailingAnchor, constant: 8),
            supportButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            supportButton.trailingAnchor.constraint(lessThanOrEqualTo: refreshButton.leadingAnchor, constant: -8)
        ])
    }

    private func rebuild() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        var completed = 0
        let total = 5

        let mic = microphoneStatus()
        completed += mic.ready ? 1 : 0
        addRow(status: mic.text, detail: mic.detail, actionTitle: mic.actionTitle, action: #selector(openMicrophone))

        let pasteReadiness = PasteTargetDetector.readiness()
        completed += pasteReadiness.severity == .blocked ? 0 : 1
        addRow(
            status: statusPrefix(for: pasteReadiness.severity) + " " + pasteReadiness.title,
            detail: pasteReadiness.detail,
            actionTitle: pasteReadiness.severity == .blocked ? "Fix" : nil,
            action: pasteReadiness.severity == .blocked ? #selector(openAccessibility) : nil
        )

        let modelReady = ModelStore.isInstalled(ModelChoice.defaultChoice)
        completed += modelReady ? 1 : 0
        addRow(
            status: modelReady ? "OK Best Accuracy is ready" : "FIX Download Best Accuracy before recording",
            detail: modelReady ? "The default English model is installed." : "This release should include the default model. Open Speed & Accuracy if it is missing.",
            actionTitle: modelReady ? nil : "Open",
            action: modelReady ? nil : #selector(openModelExplorer)
        )

        let installed = FileManager.default.fileExists(atPath: "/Applications/Plume.app")
        completed += installed ? 1 : 0
        addRow(
            status: installed ? "OK App is installed" : "FIX Move Plume to Applications",
            detail: installed ? "Running from Applications keeps macOS permissions stable across launches." : "Drag Plume.app into Applications from the DMG.",
            actionTitle: nil,
            action: nil
        )

        let signing = signingStatus()
        completed += signing.ready ? 1 : 0
        addRow(status: signing.text, detail: signing.detail, actionTitle: nil, action: nil)
        addRow(status: "OK Private by default", detail: "Core English dictation runs on this Mac. Optional language and style downloads ask first.", actionTitle: nil, action: nil)
        progressLabel.stringValue = completed == total
            ? "Setup complete. Use Try It Here for a safe first dictation."
            : "\(completed)/\(total) setup checks complete"
    }

    private func addRow(status: String, detail: String, actionTitle: String?, action: Selector?) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: status)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.maximumNumberOfLines = 0

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0

        row.addSubview(label)
        row.addSubview(detailLabel)

        var constraints = [
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.topAnchor.constraint(equalTo: row.topAnchor, constant: 5),
            detailLabel.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 3),
            detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -5)
        ]

        if let actionTitle, let action {
            let button = NSButton(title: actionTitle, target: self, action: action)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            row.addSubview(button)
            constraints.append(contentsOf: [
                button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 116),
                label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -10),
                detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -10)
            ])
        } else {
            constraints.append(label.trailingAnchor.constraint(equalTo: row.trailingAnchor))
            constraints.append(detailLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor))
        }

        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        NSLayoutConstraint.activate(constraints)
    }

    private func microphoneStatus() -> (ready: Bool, text: String, detail: String, actionTitle: String?) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return (true, "OK Microphone is ready", "Plume can hear your voice when you start recording.", nil)
        case .denied, .restricted:
            return (false, "FIX Microphone is blocked", "Allow microphone access in System Settings.", "Fix")
        case .notDetermined:
            return (false, "FIX Allow microphone access", "macOS has not asked or the prompt was not completed yet.", "Fix")
        @unknown default:
            return (false, "FIX Microphone needs attention", "Open System Settings and confirm microphone access.", "Fix")
        }
    }

    private func signingStatus() -> (ready: Bool, text: String, detail: String) {
        let appURL = URL(fileURLWithPath: "/Applications/Plume.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return (false, "FIX Install the app to finish setup", "The release app should run from Applications.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
                ? (true, "OK App identity is stable", "Code signing verifies, so macOS permissions should persist.")
                : (false, "FIX App identity needs attention", "Rebuild or install the signed release if macOS keeps asking for permissions.")
        } catch {
            return (false, "FIX Could not check app identity", "The support bundle can help diagnose this.")
        }
    }

    private func statusPrefix(for severity: PasteBackSeverity) -> String {
        switch severity {
        case .ready:
            return "OK"
        case .warning:
            return "CHECK"
        case .blocked:
            return "FIX"
        }
    }

    @objc private func refresh() {
        rebuild()
    }

    @objc private func openMicrophone() {
        onOpenMicrophone()
    }

    @objc private func openAccessibility() {
        onOpenAccessibility()
    }

    @objc private func openModelExplorer() {
        onOpenModelExplorer()
    }

    @objc private func openTryIt() {
        onOpenTryIt()
    }

    @objc private func exportSupportBundle() {
        onExportSupportBundle()
    }

    @objc private func close() {
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}
