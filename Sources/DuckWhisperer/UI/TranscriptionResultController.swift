import AppKit

final class TranscriptionResultController: NSObject {
    private let panel: NSPanel
    private let messageLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let onPasteAgain: (String) -> Void
    private let onFixPermission: () -> Void
    private let onTryHere: (String) -> Void

    init(
        onPasteAgain: @escaping (String) -> Void,
        onFixPermission: @escaping () -> Void,
        onTryHere: @escaping (String) -> Void
    ) {
        self.onPasteAgain = onPasteAgain
        self.onFixPermission = onFixPermission
        self.onTryHere = onTryHere

        let size = NSSize(width: 560, height: 300)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.title = "Your Text Is Safe"
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

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.maximumNumberOfLines = 0

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

        let pasteAgainButton = NSButton(title: "Paste Again", target: self, action: #selector(pasteAgain))
        pasteAgainButton.translatesAutoresizingMaskIntoConstraints = false
        pasteAgainButton.bezelStyle = .rounded

        let fixPermissionButton = NSButton(title: "Fix Permission", target: self, action: #selector(fixPermission))
        fixPermissionButton.translatesAutoresizingMaskIntoConstraints = false
        fixPermissionButton.bezelStyle = .rounded

        let tryHereButton = NSButton(title: "Try In DuckWhisperer", target: self, action: #selector(tryHere))
        tryHereButton.translatesAutoresizingMaskIntoConstraints = false
        tryHereButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closePanel))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(messageLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(pasteAgainButton)
        contentView.addSubview(fixPermissionButton)
        contentView.addSubview(tryHereButton)
        contentView.addSubview(copyButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            copyButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            fixPermissionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fixPermissionButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            pasteAgainButton.leadingAnchor.constraint(equalTo: fixPermissionButton.trailingAnchor, constant: 8),
            pasteAgainButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            tryHereButton.leadingAnchor.constraint(equalTo: pasteAgainButton.trailingAnchor, constant: 8),
            tryHereButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            tryHereButton.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -8)
        ])
    }

    func show(text: String, reason: String = "DuckWhisperer could not paste into the current field. Your text is copied and ready below.") {
        messageLabel.stringValue = reason
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        if !panel.isVisible {
            centerPanel()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    func close() {
        panel.orderOut(nil)
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

    @objc private func pasteAgain() {
        onPasteAgain(textView.string)
    }

    @objc private func fixPermission() {
        onFixPermission()
    }

    @objc private func tryHere() {
        onTryHere(textView.string)
        close()
    }

    @objc private func closePanel() {
        close()
    }
}
