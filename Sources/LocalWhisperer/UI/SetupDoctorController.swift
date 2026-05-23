import AppKit
import AVFoundation

final class SetupDoctorController: NSObject {
    private let window: NSWindow
    private let stackView = NSStackView()
    private let onOpenMicrophone: () -> Void
    private let onOpenAccessibility: () -> Void
    private let onOpenModelExplorer: () -> Void

    init(
        onOpenMicrophone: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onOpenModelExplorer: @escaping () -> Void
    ) {
        self.onOpenMicrophone = onOpenMicrophone
        self.onOpenAccessibility = onOpenAccessibility
        self.onOpenModelExplorer = onOpenModelExplorer
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
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

        let subtitle = NSTextField(labelWithString: "Make sure DuckWhisperer can listen, paste your words, and run privately on this Mac.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(stackView)
        contentView.addSubview(refreshButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            stackView.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: refreshButton.topAnchor, constant: -16),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),

            refreshButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            refreshButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
    }

    private func rebuild() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        addRow(status: microphoneStatus(), actionTitle: "Fix", action: #selector(openMicrophone))
        addRow(
            status: AXIsProcessTrusted() ? "ok   Paste-back is ready" : "warn Allow paste-back in System Settings",
            actionTitle: "Fix",
            action: #selector(openAccessibility)
        )
        addRow(
            status: ModelStore.isInstalled(ModelChoice.defaultChoice) ? "ok   Best Accuracy is ready" : "warn Download Best Accuracy before recording",
            actionTitle: "Open",
            action: #selector(openModelExplorer)
        )
        addRow(
            status: FileManager.default.fileExists(atPath: "/Applications/DuckWhisperer.app") ? "ok   App is installed" : "warn Move DuckWhisperer to Applications",
            actionTitle: nil,
            action: nil
        )
        addRow(status: "ok   Private: your voice stays on this Mac", actionTitle: nil, action: nil)
        addRow(status: signingStatus(), actionTitle: nil, action: nil)
    }

    private func addRow(status: String, actionTitle: String?, action: Selector?) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: status)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.maximumNumberOfLines = 0

        row.addSubview(label)

        var constraints = [
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor)
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
                label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -10)
            ])
        } else {
            constraints.append(label.trailingAnchor.constraint(equalTo: row.trailingAnchor))
        }

        stackView.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        NSLayoutConstraint.activate(constraints)
    }

    private func microphoneStatus() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "ok   Microphone is ready"
        case .denied, .restricted:
            return "fail Microphone is blocked"
        case .notDetermined:
            return "warn Allow microphone access"
        @unknown default:
            return "warn Microphone needs attention"
        }
    }

    private func signingStatus() -> String {
        let appURL = URL(fileURLWithPath: "/Applications/DuckWhisperer.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return "warn Install the app to finish setup"
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
                ? "ok   App identity is stable"
                : "warn App identity needs attention"
        } catch {
            return "warn Could not check app identity"
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

    @objc private func close() {
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}
