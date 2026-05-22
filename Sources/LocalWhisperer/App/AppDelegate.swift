import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import whisper

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let modelMenu = NSMenu()
    private let outputMenu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
    private let copyLastMenuItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript), keyEquivalent: "")
    private let translateSelectionMenuItem = NSMenuItem(title: "Translate Selection to English", action: #selector(translateSelectionFromMenu), keyEquivalent: "")
    private let preserveCapitalizationMenuItem = NSMenuItem(title: "Preserve Capitalization", action: #selector(togglePreserveCapitalization), keyEquivalent: "")
    private let hotKeyController = HotKeyController()
    private let audioCapture = AudioCapture()
    private let recordingOverlay = RecordingOverlayController()
    private let transcriptionResult = TranscriptionResultController()
    private lazy var transcriber = WhisperTranscriber(modelURL: modelURL)
    private lazy var modelExplorer = ModelExplorerController(
        currentModel: selectedModel,
        onUseModel: { [weak self] choice in
            self?.useModel(choice)
        },
        onModelsChanged: { [weak self] in
            self?.handleModelsChanged()
        }
    )
    private var state: AppState = .ready
    private var lastTranscript = ""
    private var liveTranscriptionSession: LiveTranscriptionSession?
    private var pasteTarget: PasteTarget?
    private var transcriptionProgressTimer: Timer?
    private var transcriptionProgressStartedAt: Date?
    private var transcriptionProgressTargetDuration: TimeInterval = 2.0
    private var transcriptionProgressPercent = 0

    private var selectedModel: ModelChoice {
        let choice = ModelChoice.choice(for: UserDefaults.standard.string(forKey: selectedModelIDKey))
        return ModelStore.isInstalled(choice) ? choice : ModelChoice.defaultChoice
    }

    private var selectedOutputLanguage: OutputLanguage {
        OutputLanguage.choice(for: UserDefaults.standard.string(forKey: selectedOutputLanguageIDKey))
    }

    private var preserveCapitalization: Bool {
        if UserDefaults.standard.object(forKey: preserveCapitalizationKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: preserveCapitalizationKey)
    }

    private var modelURL: URL {
        ModelStore.installedURL(for: selectedModel)
            ?? ModelStore.installedURL(for: ModelChoice.defaultChoice)
            ?? ModelStore.bundledURL(for: ModelChoice.defaultChoice)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installApplicationIcon()
        AppLog.write("launched \(buildMarker); axTrusted=\(AXIsProcessTrusted())")

        setupMenu()
        requestMicrophoneAccess()

        let hotKeyStatus = hotKeyController.register { [weak self] identifier in
            switch identifier {
            case recordHotKeyIdentifier:
                self?.toggleRecording()
            case translateSelectionHotKeyIdentifier:
                self?.translateSelectedTextToEnglish()
            default:
                break
            }
        }

        if hotKeyStatus == noErr {
            if ModelStore.isInstalled(selectedModel) {
                setState(.ready)
                preloadModel()
            } else {
                setState(.error("Download Small English in Model Explorer before recording."))
                showModelExplorer()
            }
        } else {
            setState(.error(LocalWhispererError.hotKeyFailed(hotKeyStatus).localizedDescription))
        }

        if CommandLine.arguments.contains("--open-model-explorer") {
            showModelExplorer()
        }

        if let debugPasteText {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                self.pasteTarget = PasteTargetDetector.captureFocusedEditableTarget()
                self.copyToClipboard(debugPasteText)
                self.deliverTranscript(debugPasteText)
            }
        }
    }

    private func preloadModel() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try self?.transcriber.preload()
            } catch {
                DispatchQueue.main.async {
                    self?.setState(.error(error.localizedDescription))
                }
            }
        }
    }

    private func installApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "DuckWhisperer", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }
        NSApp.applicationIconImage = icon
    }

    private func setupMenu() {
        statusItem.button?.title = ""
        statusItem.button?.image = DuckIcon.menuBarImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = appDisplayName
        statusMenuItem.isEnabled = false
        toggleMenuItem.target = self
        copyLastMenuItem.target = self
        copyLastMenuItem.isEnabled = false
        translateSelectionMenuItem.target = self
        preserveCapitalizationMenuItem.target = self

        let openMicSettings = NSMenuItem(
            title: "Open Microphone Settings",
            action: #selector(openMicrophoneSettings),
            keyEquivalent: ""
        )
        openMicSettings.target = self

        let openAccessibilitySettings = NSMenuItem(
            title: "Open Accessibility Settings for Auto-Paste",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAccessibilitySettings.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(copyLastMenuItem)
        menu.addItem(translateSelectionMenuItem)
        menu.addItem(outputMenuItem())
        menu.addItem(preserveCapitalizationMenuItem)
        let topLevelModelExplorer = NSMenuItem(
            title: "Open Model Explorer...",
            action: #selector(openModelExplorer(_:)),
            keyEquivalent: ""
        )
        topLevelModelExplorer.target = self
        menu.addItem(topLevelModelExplorer)
        menu.addItem(modelMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(openMicSettings)
        menu.addItem(openAccessibilitySettings)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        rebuildPreserveCapitalizationMenuItem()
        rebuildOutputMenu()
        rebuildModelMenu()
    }

    private func outputMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Output Language", action: nil, keyEquivalent: "")
        item.submenu = outputMenu
        return item
    }

    private func modelMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        item.submenu = modelMenu
        return item
    }

    private func rebuildOutputMenu() {
        outputMenu.removeAllItems()
        let current = selectedOutputLanguage

        for language in OutputLanguage.all {
            let item = NSMenuItem(title: language.title, action: #selector(selectOutputLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.id
            item.state = language == current ? .on : .off
            outputMenu.addItem(item)
        }
    }

    private func rebuildPreserveCapitalizationMenuItem() {
        preserveCapitalizationMenuItem.state = preserveCapitalization ? .on : .off
    }

    private func rebuildModelMenu() {
        modelMenu.removeAllItems()
        let current = selectedModel

        let explorerItem = NSMenuItem(title: "Open Model Explorer...", action: #selector(openModelExplorer(_:)), keyEquivalent: "")
        explorerItem.target = self
        modelMenu.addItem(explorerItem)
        modelMenu.addItem(NSMenuItem.separator())

        for choice in ModelChoice.all {
            let exists = ModelStore.isInstalled(choice)
            let title = exists
                ? "\(choice.title) - \(choice.detail)"
                : "\(choice.title) - not installed"
            let item = NSMenuItem(
                title: title,
                action: exists ? #selector(selectModel(_:)) : #selector(openModelExplorer(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = choice.id
            item.state = choice == current ? .on : .off
            modelMenu.addItem(item)
        }

        modelMenu.addItem(NSMenuItem.separator())
        let openInstalledModels = NSMenuItem(title: "Open Installed Models Folder", action: #selector(openInstalledModelsFolder), keyEquivalent: "")
        openInstalledModels.target = self
        modelMenu.addItem(openInstalledModels)

        let openBundledModels = NSMenuItem(title: "Open Bundled Models Folder", action: #selector(openBundledModelsFolder), keyEquivalent: "")
        openBundledModels.target = self
        modelMenu.addItem(openBundledModels)
    }

    private func setState(_ newState: AppState) {
        state = newState
        statusItem.button?.title = ""
        statusItem.button?.image = DuckIcon.menuBarImage()
        statusItem.button?.toolTip = "\(appDisplayName): \(newState.statusText)"
        let formattingText = preserveCapitalization ? "Caps On" : "Caps Off"
        statusMenuItem.title = "\(newState.statusText) - \(selectedModel.title) -> \(selectedOutputLanguage.title) - \(formattingText)"

        switch newState {
        case .ready, .error:
            stopTranscriptionProgress()
            recordingOverlay.hide()
            toggleMenuItem.title = "Start Recording"
            toggleMenuItem.isEnabled = true
        case .recording:
            recordingOverlay.show(progressPercent: nil)
            toggleMenuItem.title = "Stop and Paste"
            toggleMenuItem.isEnabled = true
        case .transcribing:
            recordingOverlay.show(progressPercent: transcriptionProgressPercent)
            toggleMenuItem.title = "Transcribing..."
            toggleMenuItem.isEnabled = false
        }

        copyLastMenuItem.isEnabled = !lastTranscript.isEmpty
        translateSelectionMenuItem.isEnabled = state != .recording && state != .transcribing
        rebuildPreserveCapitalizationMenuItem()
    }

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    private func requestAccessibilityAccessIfNeeded() {
        guard !AXIsProcessTrusted() else {
            return
        }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        AppLog.write("requested Accessibility permission prompt")
    }

    private func logAccessibilityStateForRecording() {
        AppLog.write("recording start; axTrusted=\(AXIsProcessTrusted())")
    }

    @objc private func toggleRecordingFromMenu() {
        toggleRecording()
    }

    @objc private func translateSelectionFromMenu() {
        translateSelectedTextToEnglish()
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        useModel(ModelChoice.choice(for: id))
    }

    private func useModel(_ choice: ModelChoice) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let modelURL = ModelStore.installedURL(for: choice) else {
            showModelExplorer()
            return
        }

        UserDefaults.standard.set(choice.id, forKey: selectedModelIDKey)
        transcriber.setModelURL(modelURL)
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel)
        setState(.ready)
        preloadModel()
    }

    private func handleModelsChanged() {
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel)
        if ModelStore.isInstalled(selectedModel) {
            setState(.ready)
            preloadModel()
        } else {
            setState(state)
        }
    }

    @objc private func selectOutputLanguage(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        let language = OutputLanguage.choice(for: id)
        UserDefaults.standard.set(language.id, forKey: selectedOutputLanguageIDKey)
        rebuildOutputMenu()
        setState(.ready)
    }

    @objc private func togglePreserveCapitalization() {
        UserDefaults.standard.set(!preserveCapitalization, forKey: preserveCapitalizationKey)
        rebuildPreserveCapitalizationMenuItem()
        setState(state)
    }

    private func translateSelectedTextToEnglish() {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        let outputLanguage = selectedOutputLanguage
        guard let sourceCode = outputLanguage.translationTargetCode else {
            transcriptionResult.show(text: "Set Output Language to French or Dutch, select text in that language, then press Option+X.")
            return
        }

        captureSelectedText { [weak self] selectedText in
            guard let self else { return }
            guard let selectedText else {
                self.transcriptionResult.show(text: "No selected text found. Select text in the current output language, then press Option+X.")
                NSSound.beep()
                return
            }

            self.statusMenuItem.title = "Translating selection to English..."
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }

                do {
                    let translated = try LocalTranslator.translate(selectedText, from: sourceCode, to: "en")
                    DispatchQueue.main.async {
                        AppLog.write("translated selected \(outputLanguage.title) text to English")
                        self.lastTranscript = translated
                        self.copyLastMenuItem.isEnabled = true
                        self.transcriptionResult.show(text: translated)
                        self.setState(self.state)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.setState(.error(error.localizedDescription))
                        self.transcriptionResult.show(text: error.localizedDescription)
                        NSSound.beep()
                    }
                }
            }
        }
    }

    private func captureSelectedText(completion: @escaping (String?) -> Void) {
        if let selectedText = PasteTargetDetector.selectedTextFromFocusedTarget() {
            completion(selectedText)
            return
        }

        guard AXIsProcessTrusted() else {
            AppLog.write("selection translation skipped; Accessibility is not trusted")
            completion(nil)
            return
        }

        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems?.compactMap { $0.copy() as? NSPasteboardItem } ?? []
        pasteboard.clearContents()

        guard postCopyShortcut() else {
            restorePasteboardItems(previousItems)
            completion(nil)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let copiedText = pasteboard.string(forType: .string)
            self.restorePasteboardItems(previousItems)

            let trimmed = copiedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(trimmed.isEmpty ? nil : copiedText)
        }
    }

    private func restorePasteboardItems(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private func postCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        let keyCode: CGKeyCode = 8
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func toggleRecording() {
        switch state {
        case .ready, .error:
            startRecording()
        case .recording:
            stopTranscribeAndPaste()
        case .transcribing:
            NSSound.beep()
        }
    }

    private func startRecording() {
        guard ModelStore.isInstalled(selectedModel) else {
            setState(.error("Download a speech model in Model Explorer before recording."))
            showModelExplorer()
            NSSound.beep()
            return
        }

        logAccessibilityStateForRecording()

        do {
            pasteTarget = PasteTargetDetector.captureFocusedEditableTarget()
            try audioCapture.start()
            let session = LiveTranscriptionSession(audioCapture: audioCapture, transcriber: transcriber)
            liveTranscriptionSession = session
            session.start()
            setState(.recording)
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
        }
    }

    private func stopTranscribeAndPaste() {
        let samples: [Float]
        let liveSession = liveTranscriptionSession
        liveTranscriptionSession = nil

        do {
            samples = try audioCapture.stop()
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
            return
        }

        setState(.transcribing)
        startTranscriptionProgress(audioDuration: Double(samples.count) / Double(WHISPER_SAMPLE_RATE))
        let outputLanguage = selectedOutputLanguage
        let shouldPreserveCapitalization = preserveCapitalization

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let startedAt = Date()
                let transcript = try liveSession?.finish(with: samples)
                    ?? self.transcriber.transcribe(samples: samples)
                let translatedOutput = try LocalTranslator.translate(transcript, to: outputLanguage)
                let languageOutput = self.applyLanguageOutput(to: translatedOutput, outputLanguage: outputLanguage)
                let output = self.applyOutputFormatting(
                    to: languageOutput,
                    preserveCapitalization: shouldPreserveCapitalization
                )
                let elapsed = Date().timeIntervalSince(startedAt)

                DispatchQueue.main.async {
                    self.completeTranscriptionProgress()
                    AppLog.write(String(format: "transcribed %.2fs of audio in %.2fs", Double(samples.count) / Double(WHISPER_SAMPLE_RATE), elapsed))
                    self.lastTranscript = output
                    self.copyToClipboard(output)
                    self.deliverTranscript(output)
                }
            } catch {
                DispatchQueue.main.async {
                    self.stopTranscriptionProgress()
                    self.setState(.error(error.localizedDescription))
                    NSSound.beep()
                }
            }
        }
    }

    private func startTranscriptionProgress(audioDuration: TimeInterval) {
        transcriptionProgressTimer?.invalidate()
        transcriptionProgressPercent = 0
        transcriptionProgressStartedAt = Date()
        transcriptionProgressTargetDuration = max(1.2, min(8.0, 1.0 + audioDuration * 0.12))
        recordingOverlay.setProgress(0)

        transcriptionProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self,
                  let startedAt = self.transcriptionProgressStartedAt,
                  self.state == .transcribing
            else {
                return
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let estimatedProgress = Int((elapsed / self.transcriptionProgressTargetDuration) * 95.0)
            self.transcriptionProgressPercent = max(
                self.transcriptionProgressPercent,
                min(95, estimatedProgress)
            )
            self.recordingOverlay.setProgress(self.transcriptionProgressPercent)
        }
    }

    private func completeTranscriptionProgress() {
        transcriptionProgressTimer?.invalidate()
        transcriptionProgressTimer = nil
        transcriptionProgressStartedAt = nil
        transcriptionProgressPercent = 100
        recordingOverlay.setProgress(100)
    }

    private func stopTranscriptionProgress() {
        transcriptionProgressTimer?.invalidate()
        transcriptionProgressTimer = nil
        transcriptionProgressStartedAt = nil
        transcriptionProgressPercent = 0
        recordingOverlay.setProgress(nil)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func applyLanguageOutput(to text: String, outputLanguage: OutputLanguage) -> String {
        switch outputLanguage.id {
        case "duck":
            return DuckSpeech.render(text)
        default:
            return text
        }
    }

    private func applyOutputFormatting(to text: String, preserveCapitalization: Bool) -> String {
        guard !preserveCapitalization else {
            return text
        }
        return text.localizedLowercase
    }

    private func deliverTranscript(_ output: String) {
        let target = pasteTarget
        pasteTarget = nil

        guard AXIsProcessTrusted() else {
            AppLog.write("delivery fallback; Accessibility not trusted, transcript copied and transcript window shown")
            transcriptionResult.show(text: output)
            setState(.ready)
            return
        }

        let finish: (_ allowFocusedCheckBypass: Bool) -> Void = { [weak self] allowFocusedCheckBypass in
            guard let self else { return }
            if !self.pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: allowFocusedCheckBypass) {
                self.transcriptionResult.show(text: output)
            }
            self.setState(.ready)
        }

        guard let target
        else {
            AppLog.write("delivery target missing; attempting focused paste")
            finish(false)
            return
        }

        AppLog.write("delivery start target=\(targetDescription(target)) synthetic=\(shouldUseSyntheticTyping(for: target))")

        if target.element == nil {
            AppLog.write("blind paste path for AX-invisible target; axTrusted=\(AXIsProcessTrusted()) app=\(target.application?.localizedName ?? "nil")")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.setState(.ready)
                    return
                }
                finish(true)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
        if let application = target.application, !application.isTerminated {
            application.activate(options: [.activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let restoredFocus = PasteTargetDetector.focusCapturedTarget(target)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.setState(.ready)
                    return
                }
                if PasteTargetDetector.insertTextDirectly(output, into: target) {
                    self.setState(.ready)
                    return
                }
                finish(restoredFocus || target.application != nil)
            }
        }
    }

    private func shouldUseSyntheticTyping(for target: PasteTarget) -> Bool {
        let appName = target.application?.localizedName?.lowercased() ?? ""
        return appName.contains("codex")
    }

    private func targetDescription(_ target: PasteTarget) -> String {
        let appName = target.application?.localizedName ?? "nil"
        let bundleID = target.application?.bundleIdentifier ?? "nil"
        let pidText = target.pid.map { String($0) } ?? "nil"
        return "app=\(appName) bundle=\(bundleID) pid=\(pidText) element=\(target.element == nil ? "nil" : "editable")"
    }

    private func typeTextWithKeyboard(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            AppLog.write("synthetic typing skipped; Accessibility is not trusted")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            AppLog.write("synthetic typing skipped; could not create event source")
            return false
        }

        let units = Array(text.utf16)
        for unit in units {
            var character = unit
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                AppLog.write("synthetic typing failed; could not create key event")
                return false
            }

            keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            usleep(700)
        }

        AppLog.write("synthetic typing posted \(units.count) UTF-16 units")
        return true
    }

    private func pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: Bool = false) -> Bool {
        guard AXIsProcessTrusted() else {
            AppLog.write("paste skipped; Accessibility is not trusted")
            return false
        }

        guard allowWithoutFocusedCheck || PasteTargetDetector.canAttemptPasteIntoFocusedTarget() else {
            AppLog.write("paste skipped; no focused editable target")
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        AppLog.write("paste command posted")
        return true
    }

    @objc private func copyLastTranscript() {
        guard !lastTranscript.isEmpty else {
            return
        }
        copyToClipboard(lastTranscript)
    }

    @objc private func openMicrophoneSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityAccessIfNeeded()
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    @objc private func openModelExplorer(_ sender: Any?) {
        AppLog.write("open model explorer action fired from \(String(describing: type(of: sender as Any)))")
        showModelExplorer()
    }

    private func showModelExplorer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            AppLog.write("presenting model explorer after menu close")
            self.modelExplorer.show(currentModel: self.selectedModel)
        }
    }

    @objc private func openInstalledModelsFolder() {
        do {
            try FileManager.default.createDirectory(at: ModelStore.userModelsURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(ModelStore.userModelsURL)
        } catch {
            setState(.error(error.localizedDescription))
            NSSound.beep()
        }
    }

    @objc private func openBundledModelsFolder() {
        NSWorkspace.shared.open(ModelStore.bundledModelsURL)
    }

    private func openSettings(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
