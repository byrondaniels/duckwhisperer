import AppKit

final class TranscriptHistoryController: NSObject {
    private let panel: NSPanel
    private let searchField = NSSearchField()
    private let statsLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private var entries: [TranscriptHistoryEntry] = []

    override init() {
        let size = NSSize(width: 680, height: 460)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.title = "History"
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = contentView

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search your text"
        searchField.target = self
        searchField.action = #selector(rebuild)

        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statsLabel.textColor = .secondaryLabelColor
        statsLabel.lineBreakMode = .byTruncatingTail

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        scrollView.documentView = textView

        let copyButton = NSButton(title: "Copy Visible", target: self, action: #selector(copyVisible))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .rounded

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearHistory))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(searchField)
        contentView.addSubview(statsLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(copyButton)
        contentView.addSubview(clearButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            statsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            statsLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -14),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            clearButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            clearButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
    }

    func show() {
        entries = TranscriptHistoryStore.entries()
        rebuild()
        if !panel.isVisible {
            panel.center()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    @objc private func rebuild() {
        statsLabel.stringValue = DictationStatsStore.current().detailSummary
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let visible = entries.filter { entry in
            query.isEmpty ||
                entry.text.localizedLowercase.contains(query) ||
                entry.appName.localizedLowercase.contains(query) ||
                entry.writingProfileTitle.localizedLowercase.contains(query)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        textView.string = visible.map { entry in
            """
            \(formatter.string(from: entry.createdAt)) · \(entry.appName) · \(entry.writingProfileTitle) · \(entry.outputLanguageTitle)
            \(entry.text)
            """
        }.joined(separator: "\n\n---\n\n")
    }

    @objc private func copyVisible() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func clearHistory() {
        TranscriptHistoryStore.clear()
        entries = []
        rebuild()
    }

    @objc private func close() {
        panel.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}
