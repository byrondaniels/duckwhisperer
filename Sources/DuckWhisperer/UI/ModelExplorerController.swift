import AppKit
import Foundation

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}
final class ModelExplorerController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let scrollView = NSScrollView()
    private let documentView = FlippedDocumentView()
    private let stackView = NSStackView()
    private var currentModel: ModelChoice
    private var currentInputLanguage: InputLanguageChoice
    private let onUseModel: (ModelChoice) -> Void
    private let onModelsChanged: () -> Void
    private var downloadingModelKeys = Set<String>()
    private var installingTranslationPackIDs = Set<String>()

    init(
        currentModel: ModelChoice,
        onUseModel: @escaping (ModelChoice) -> Void,
        onModelsChanged: @escaping () -> Void
    ) {
        self.currentModel = currentModel
        self.currentInputLanguage = .defaultChoice
        self.onUseModel = onUseModel
        self.onModelsChanged = onModelsChanged

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Speed & Accuracy"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 460)
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        super.init()
        window.delegate = self
        buildWindow()
        rebuild()
    }

    func show(currentModel: ModelChoice, inputLanguage: InputLanguageChoice) {
        self.currentModel = currentModel
        self.currentInputLanguage = inputLanguage
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

    func refresh(currentModel: ModelChoice, inputLanguage: InputLanguageChoice) {
        self.currentModel = currentModel
        self.currentInputLanguage = inputLanguage
        rebuild()
    }

    private func buildWindow() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = makeLabel("Speed & Accuracy", font: .boldSystemFont(ofSize: 20))
        let subtitleLabel = makeLabel(
            "Choose how fast DuckWhisperer should feel. Extra downloads only happen when you approve them.",
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

        let inputSummary = currentInputLanguage.isEnglish
            ? "Speaking: English. English uses its own smaller speech model."
            : "Speaking: \(currentInputLanguage.title). Non-English input uses one shared multilingual speech model per speed."
        let inputText = makeLabel(inputSummary, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        addFullWidthRow(inputText)

        addSectionTitle("Speed")
        for choice in ModelChoice.all {
            addFullWidthRow(makeModelRow(for: choice))
        }

        addSectionTitle("Translation Add-ons")
        for pack in TranslationPackChoice.visiblePacks(for: currentInputLanguage) {
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

        let title = choice.friendlyMenuTitle
        let titleLabel = makeLabel(title, font: .boldSystemFont(ofSize: 14))
        let detailLabel = makeLabel(choice.friendlyDetail, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let statusLabel = makeLabel(
            "\(choice.diskSizeText(for: currentInputLanguage)) · \(choice.languageScopeText(for: currentInputLanguage)) · \(statusText(for: choice))",
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
        if downloadingModelKeys.contains(downloadKey(for: choice)) {
            return "Downloading..."
        }
        if ModelStore.installedURL(for: choice, inputLanguage: currentInputLanguage) != nil {
            return "Installed"
        }
        return "Not installed"
    }

    private func actionTitle(for choice: ModelChoice) -> String {
        if downloadingModelKeys.contains(downloadKey(for: choice)) {
            return "Downloading..."
        }
        guard ModelStore.isInstalled(choice, inputLanguage: currentInputLanguage) else {
            return "Download"
        }
        return choice == currentModel ? "Selected" : "Use"
    }

    private func canAct(on choice: ModelChoice) -> Bool {
        if downloadingModelKeys.contains(downloadKey(for: choice)) {
            return false
        }
        if ModelStore.isInstalled(choice, inputLanguage: currentInputLanguage), choice == currentModel {
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

        if ModelStore.isInstalled(choice, inputLanguage: currentInputLanguage) {
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
        let inputLanguage = currentInputLanguage
        let asset = choice.asset(for: inputLanguage)
        let alert = NSAlert()
        alert.messageText = inputLanguage.isEnglish ? "Download \(choice.friendlyTitle)?" : "Download Multilingual Speech Model?"
        let unlockText = inputLanguage.isEnglish
            ? "This installs \(asset.filename), the English-only Whisper file."
            : "\(inputLanguage.title) uses \(asset.filename), one shared multilingual Whisper file. It unlocks all non-English input choices for this speed; DuckWhisperer is not downloading a separate pack for each language."
        alert.informativeText = "\(unlockText) Download size: \(asset.downloadSizeText). Nothing downloads unless you choose Download."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let key = downloadKey(for: choice)
        downloadingModelKeys.insert(key)
        rebuild()

        URLSession.shared.downloadTask(with: choice.downloadURL(for: inputLanguage)) { [weak self] temporaryURL, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.downloadingModelKeys.remove(key)

                do {
                    if let error {
                        throw DuckWhispererError.modelDownloadFailed(error.localizedDescription)
                    }
                    if let response = response as? HTTPURLResponse,
                       !(200...299).contains(response.statusCode) {
                        throw DuckWhispererError.modelDownloadFailed("HTTP \(response.statusCode) while downloading \(asset.filename).")
                    }
                    guard let temporaryURL else {
                        throw DuckWhispererError.modelDownloadFailed("No downloaded file was returned.")
                    }
                    try ModelStore.installDownloadedModel(from: temporaryURL, for: choice, inputLanguage: inputLanguage)
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

    private func downloadKey(for choice: ModelChoice) -> String {
        choice.filename(for: currentInputLanguage)
    }

    private func confirmAndInstall(_ pack: TranslationPackChoice) {
        let alert = NSAlert()
        alert.messageText = "Install \(pack.title)?"
        let runtimeNote: String
        switch pack.backend {
        case .argos:
            runtimeNote = "This adds one local Argos translation package."
        case .huggingFaceMarian(_):
            runtimeNote = "This adds one dedicated Helsinki/OPUS text translator. The first dedicated translator may also install a local Python ML runtime."
        }
        alert.informativeText = "\(runtimeNote) Download size: \(pack.downloadSizeText). It stays on this Mac."
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
