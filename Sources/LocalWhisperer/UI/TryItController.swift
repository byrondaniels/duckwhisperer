import AppKit

final class TryItController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let textView = NSTextView()
    private var lastInsertedRange: NSRange?

    override init() {
        let size = NSSize(width: 560, height: 360)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        window.title = "Try DuckWhisperer"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 280)
        window.delegate = self
        buildWindow(size: size)
    }

    var shouldReceiveTranscript: Bool {
        window.isVisible && window.isKeyWindow
    }

    func show() {
        if !window.isVisible {
            window.center()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    func insertTranscript(_ text: String) {
        let insertionPoint = textView.selectedRange().location
        let prefix = textView.string.isEmpty || insertionPoint == 0 ? "" : "\n"
        let insertion = "\(prefix)\(text)"
        textView.insertText(insertion, replacementRange: textView.selectedRange())
        lastInsertedRange = NSRange(location: insertionPoint, length: insertion.utf16.count)
        textView.scrollRangeToVisible(NSRange(location: textView.string.utf16.count, length: 0))
    }

    func undoLastInsertion() -> Bool {
        guard let lastInsertedRange,
              lastInsertedRange.location + lastInsertedRange.length <= textView.string.utf16.count
        else {
            return false
        }

        textView.textStorage?.replaceCharacters(in: lastInsertedRange, with: "")
        self.lastInsertedRange = nil
        return true
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func buildWindow(size: NSSize) {
        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let title = NSTextField(labelWithString: "Try it here")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .boldSystemFont(ofSize: 20)

        let subtitle = NSTextField(labelWithString: "Click in the box, press Option+Space, speak, then press Option+Space again.")
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 0

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearText))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded

        let focusButton = NSButton(title: "Focus Text Box", target: self, action: #selector(focusTextBox))
        focusButton.translatesAutoresizingMaskIntoConstraints = false
        focusButton.bezelStyle = .rounded

        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(scrollView)
        contentView.addSubview(clearButton)
        contentView.addSubview(focusButton)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            title.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -12),

            focusButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            focusButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            clearButton.trailingAnchor.constraint(equalTo: focusButton.leadingAnchor, constant: -8),
            clearButton.centerYAnchor.constraint(equalTo: focusButton.centerYAnchor)
        ])
    }

    @objc private func clearText() {
        textView.string = ""
        lastInsertedRange = nil
        window.makeFirstResponder(textView)
    }

    @objc private func focusTextBox() {
        window.makeFirstResponder(textView)
    }
}
