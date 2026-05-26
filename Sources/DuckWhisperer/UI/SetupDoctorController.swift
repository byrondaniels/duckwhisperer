import AppKit
import AVFoundation

private enum ReadinessLevel {
    case ok
    case warning
    case blocked

    var symbolName: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        }
    }

    var color: NSColor {
        switch self {
        case .ok: return .systemGreen
        case .warning: return .systemYellow
        case .blocked: return .systemRed
        }
    }
}

final class SetupDoctorController: NSObject {
    private let window: NSWindow
    private let stackView = NSStackView()
    private let progressLabel = NSTextField(labelWithString: "")
    private let progressIcon = NSImageView()
    private var isDownloadingModel = false
    private let onOpenMicrophone: () -> Void
    private let onOpenAccessibility: () -> Void
    private let onOpenModelExplorer: () -> Void
    private let onDownloadDefaultModel: () -> Void
    private let onOpenTryIt: () -> Void
    private let onExportSupportBundle: () -> Void

    init(
        onOpenMicrophone: @escaping () -> Void,
        onOpenAccessibility: @escaping () -> Void,
        onOpenModelExplorer: @escaping () -> Void,
        onDownloadDefaultModel: @escaping () -> Void,
        onOpenTryIt: @escaping () -> Void,
        onExportSupportBundle: @escaping () -> Void
    ) {
        self.onOpenMicrophone = onOpenMicrophone
        self.onOpenAccessibility = onOpenAccessibility
        self.onOpenModelExplorer = onOpenModelExplorer
        self.onDownloadDefaultModel = onDownloadDefaultModel
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

        let subtitle = NSTextField(labelWithString: "Make sure DuckWhisperer can listen, paste your words, and run privately on this Mac.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0

        progressIcon.translatesAutoresizingMaskIntoConstraints = false
        progressIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        progressIcon.contentTintColor = .systemGreen
        progressIcon.isHidden = true

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor = .secondaryLabelColor
        progressLabel.maximumNumberOfLines = 0

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
        contentView.addSubview(progressIcon)
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

            progressIcon.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            progressIcon.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            progressIcon.widthAnchor.constraint(equalToConstant: 26),
            progressIcon.heightAnchor.constraint(equalToConstant: 26),

            progressLabel.leadingAnchor.constraint(equalTo: progressIcon.trailingAnchor, constant: 8),
            progressLabel.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            progressLabel.centerYAnchor.constraint(equalTo: progressIcon.centerYAnchor),

            stackView.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: progressIcon.bottomAnchor, constant: 16),
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
        let total = 3

        let mic = microphoneStatus()
        completed += mic.level == .ok ? 1 : 0
        addRow(level: mic.level, title: mic.title, detail: mic.detail, actionTitle: mic.actionTitle, action: #selector(openMicrophone))

        let pasteReadiness = PasteTargetDetector.readiness()
        let pasteLevel: ReadinessLevel = {
            switch pasteReadiness.severity {
            case .ready: return .ok
            case .warning: return .warning
            case .blocked: return .blocked
            }
        }()
        completed += pasteReadiness.severity == .blocked ? 0 : 1
        addRow(
            level: pasteLevel,
            title: pasteReadiness.title,
            detail: pasteReadiness.detail,
            actionTitle: pasteReadiness.severity == .blocked ? "Fix" : nil,
            action: pasteReadiness.severity == .blocked ? #selector(openAccessibility) : nil
        )

        let defaultModel = ModelChoice.defaultChoice
        let modelReady = ModelStore.isInstalled(defaultModel)
        completed += modelReady ? 1 : 0
        if isDownloadingModel {
            addRow(
                level: .warning,
                title: "Downloading \(defaultModel.friendlyTitle) speech...",
                detail: "Hang tight — the \(defaultModel.englishAsset.downloadSizeText) model is downloading. This can take a minute on first run.",
                actionTitle: nil,
                action: nil
            )
        } else {
            addRow(
                level: modelReady ? .ok : .blocked,
                title: modelReady ? "\(defaultModel.friendlyTitle) speech is ready" : "Download \(defaultModel.friendlyTitle) speech to start",
                detail: modelReady ? "The default English model is installed." : "Tap Download to get the \(defaultModel.friendlyTitle) English model (\(defaultModel.englishAsset.downloadSizeText)).",
                actionTitle: modelReady ? nil : "Download",
                action: modelReady ? nil : #selector(downloadModel)
            )
        }

        if completed == total {
            progressIcon.isHidden = false
            progressIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "All set")
            progressIcon.contentTintColor = .systemGreen
            progressLabel.stringValue = "All set! Press \(RecordShortcutPreset.currentSelected.title) anywhere to dictate."
            progressLabel.font = .systemFont(ofSize: 16, weight: .bold)
            progressLabel.textColor = .systemGreen
        } else {
            progressIcon.isHidden = true
            progressLabel.stringValue = "\(completed)/\(total) setup checks complete"
            progressLabel.font = .systemFont(ofSize: 12, weight: .semibold)
            progressLabel.textColor = .secondaryLabelColor
        }
    }

    private func addRow(level: ReadinessLevel, title: String, detail: String, actionTitle: String?, action: Selector?) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.image = NSImage(systemSymbolName: level.symbolName, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        icon.contentTintColor = level.color

        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.maximumNumberOfLines = 0

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.maximumNumberOfLines = 0

        row.addSubview(icon)
        row.addSubview(label)
        row.addSubview(detailLabel)

        var constraints = [
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.topAnchor.constraint(equalTo: row.topAnchor, constant: 6),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
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

    private func microphoneStatus() -> (level: ReadinessLevel, title: String, detail: String, actionTitle: String?) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return (.ok, "Microphone is ready", "DuckWhisperer can hear your voice when you start recording.", nil)
        case .denied, .restricted:
            return (.blocked, "Microphone is blocked", "Allow microphone access in System Settings.", "Fix")
        case .notDetermined:
            return (.blocked, "Allow microphone access", "macOS has not asked or the prompt was not completed yet.", "Fix")
        @unknown default:
            return (.blocked, "Microphone needs attention", "Open System Settings and confirm microphone access.", "Fix")
        }
    }

    func refreshChecks() {
        rebuild()
    }

    func setModelDownloading(_ downloading: Bool) {
        isDownloadingModel = downloading
        rebuild()
    }

    @objc private func refresh() {
        rebuild()
    }

    @objc private func openMicrophone() {
        onOpenMicrophone()
    }

    @objc private func downloadModel() {
        onDownloadDefaultModel()
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
