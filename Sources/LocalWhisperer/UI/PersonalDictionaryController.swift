import AppKit

final class PersonalDictionaryController: NSObject {
    private let panel: NSPanel
    private let textView = NSTextView()
    private let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let size = NSSize(width: 520, height: 360)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.title = "Personal Dictionary"
        panel.isReleasedWhenClosed = false
        panel.level = .floating

        let contentView = NSView(frame: NSRect(origin: .zero, size: size))
        panel.contentView = contentView

        let helpLabel = NSTextField(labelWithString: "One replacement per line. Example: open ai = OpenAI")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.font = .systemFont(ofSize: 13)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        scrollView.documentView = textView

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded

        contentView.addSubview(helpLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(saveButton)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            helpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            helpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            helpLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: helpLabel.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -14),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            saveButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            saveButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor)
        ])
    }

    func show() {
        textView.string = UserDefaults.standard.string(forKey: personalDictionaryTextKey) ?? ""
        if !panel.isVisible {
            panel.center()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    @objc private func save() {
        UserDefaults.standard.set(textView.string, forKey: personalDictionaryTextKey)
        onSave()
        panel.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func close() {
        panel.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}
