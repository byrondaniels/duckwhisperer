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
    private let profileMenu = NSMenu()
    private let performanceMenu = NSMenu()
    private let historyMenu = NSMenu()
    private let appDefaultsMenu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let autoPastePermissionMenuItem = NSMenuItem(title: "Auto-Paste Permission: Checking...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
    private let copyLastMenuItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript), keyEquivalent: "")
    private let preserveCapitalizationMenuItem = NSMenuItem(title: "Preserve Capitalization", action: #selector(togglePreserveCapitalization), keyEquivalent: "")
    private let audioDuckingMenuItem = NSMenuItem(title: "Audio Ducking", action: #selector(toggleAudioDucking), keyEquivalent: "")
    private let hotKeyController = HotKeyController()
    private let audioCapture = AudioCapture()
    private let audioDucker = AudioDucker()
    private let recordingOverlay = RecordingOverlayController()
    private let transcriptionResult = TranscriptionResultController()
    private lazy var personalDictionaryController = PersonalDictionaryController { [weak self] in
        self?.refreshPermissionUI()
    }
    private lazy var transcriptHistoryController = TranscriptHistoryController()
    private lazy var setupDoctorController = SetupDoctorController(
        onOpenMicrophone: { [weak self] in self?.openMicrophoneSettings() },
        onOpenAccessibility: { [weak self] in self?.openAccessibilitySettings() },
        onOpenModelExplorer: { [weak self] in self?.showModelExplorer() }
    )
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
    private var permissionRefreshTimer: Timer?
    private var recordingLevelTimer: Timer?
    private var transcriptionProgressStartedAt: Date?
    private var transcriptionProgressTargetDuration: TimeInterval = 2.0
    private var transcriptionProgressPercent = 0
    private var activeTranscriptionID: UUID?
    private var recordingStartedAt: Date?
    private var activeAppName: String?
    private var activeOutputLanguage: OutputLanguage?
    private var activeWritingProfile: WritingProfile?
    private var activeModelChoice: ModelChoice?

    private var selectedModel: ModelChoice {
        let choice = ModelChoice.choice(for: UserDefaults.standard.string(forKey: selectedModelIDKey))
        return ModelStore.isInstalled(choice) ? choice : ModelChoice.defaultChoice
    }

    private var selectedOutputLanguage: OutputLanguage {
        OutputLanguage.choice(for: UserDefaults.standard.string(forKey: selectedOutputLanguageIDKey))
    }

    private var selectedWritingProfile: WritingProfile {
        WritingProfile.choice(for: UserDefaults.standard.string(forKey: selectedWritingProfileIDKey))
    }

    private var audioDuckingEnabled: Bool {
        UserDefaults.standard.bool(forKey: audioDuckingEnabledKey)
    }

    private var personalDictionaryEntries: [PersonalDictionaryEntry] {
        PersonalDictionary.entries(from: UserDefaults.standard.string(forKey: personalDictionaryTextKey) ?? "")
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
        startPermissionRefreshTimer()

        let hotKeyStatus = hotKeyController.register { [weak self] identifier in
            switch identifier {
            case recordHotKeyIdentifier:
                self?.toggleRecording()
            case cancelHotKeyIdentifier:
                self?.cancelActiveDictation()
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

        if !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) {
            UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showSetupDoctor()
            }
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

    func applicationWillTerminate(_ notification: Notification) {
        permissionRefreshTimer?.invalidate()
        recordingLevelTimer?.invalidate()
        transcriptionProgressTimer?.invalidate()
        audioDucker.restore()
        hotKeyController.unregisterCancelHotKey()
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
        autoPastePermissionMenuItem.target = self
        toggleMenuItem.target = self
        copyLastMenuItem.target = self
        copyLastMenuItem.isEnabled = false
        preserveCapitalizationMenuItem.target = self
        audioDuckingMenuItem.target = self

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
        menu.addItem(autoPastePermissionMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(copyLastMenuItem)
        menu.addItem(historyMenuItem())
        menu.addItem(outputMenuItem())
        menu.addItem(profileMenuItem())
        menu.addItem(performanceMenuItem())
        menu.addItem(preserveCapitalizationMenuItem)
        menu.addItem(audioDuckingMenuItem)
        menu.addItem(appDefaultsMenuItem())
        let personalDictionaryItem = NSMenuItem(
            title: "Personal Dictionary...",
            action: #selector(openPersonalDictionary),
            keyEquivalent: ""
        )
        personalDictionaryItem.target = self
        menu.addItem(personalDictionaryItem)
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
        let setupDoctorItem = NSMenuItem(
            title: "Setup Doctor...",
            action: #selector(openSetupDoctor),
            keyEquivalent: ""
        )
        setupDoctorItem.target = self
        menu.addItem(setupDoctorItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        rebuildPreserveCapitalizationMenuItem()
        rebuildAudioDuckingMenuItem()
        rebuildOutputMenu()
        rebuildProfileMenu()
        rebuildPerformanceMenu()
        rebuildHistoryMenu()
        rebuildAppDefaultsMenu()
        rebuildModelMenu()
        refreshPermissionUI()
    }

    private func outputMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Output Language", action: nil, keyEquivalent: "")
        item.submenu = outputMenu
        return item
    }

    private func profileMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Writing Profile", action: nil, keyEquivalent: "")
        item.submenu = profileMenu
        return item
    }

    private func performanceMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Speed / Quality", action: nil, keyEquivalent: "")
        item.submenu = performanceMenu
        return item
    }

    private func historyMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Transcript History", action: nil, keyEquivalent: "")
        item.submenu = historyMenu
        return item
    }

    private func appDefaultsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Per-App Defaults", action: nil, keyEquivalent: "")
        item.submenu = appDefaultsMenu
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

    private func rebuildProfileMenu() {
        profileMenu.removeAllItems()
        let current = selectedWritingProfile

        for profile in WritingProfile.all {
            let item = NSMenuItem(title: "\(profile.title) - \(profile.detail)", action: #selector(selectWritingProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id
            item.state = profile == current ? .on : .off
            profileMenu.addItem(item)
        }
    }

    private func rebuildPerformanceMenu() {
        performanceMenu.removeAllItems()
        let mappings: [(title: String, model: ModelChoice)] = [
            ("Fast - Tiny English", ModelChoice.choice(for: "tiny-en")),
            ("Balanced - Base English", ModelChoice.choice(for: "base-en")),
            ("Accurate - Small English", ModelChoice.choice(for: "small-en"))
        ]

        for mapping in mappings {
            let installed = ModelStore.isInstalled(mapping.model)
            let title = installed ? mapping.title : "\(mapping.title) - not installed"
            let item = NSMenuItem(
                title: title,
                action: installed ? #selector(selectPerformanceModel(_:)) : #selector(openModelExplorer(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mapping.model.id
            item.state = mapping.model == selectedModel ? .on : .off
            performanceMenu.addItem(item)
        }
    }

    private func rebuildHistoryMenu() {
        historyMenu.removeAllItems()

        let openItem = NSMenuItem(title: "Open History...", action: #selector(openTranscriptHistory), keyEquivalent: "")
        openItem.target = self
        historyMenu.addItem(openItem)

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearTranscriptHistory), keyEquivalent: "")
        clearItem.target = self
        historyMenu.addItem(clearItem)

        let entries = TranscriptHistoryStore.entries().prefix(6)
        guard !entries.isEmpty else {
            historyMenu.addItem(NSMenuItem.separator())
            let emptyItem = NSMenuItem(title: "No transcripts yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
            return
        }

        historyMenu.addItem(NSMenuItem.separator())
        for entry in entries {
            let title = entry.text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            let item = NSMenuItem(
                title: String(title.prefix(72)),
                action: #selector(copyHistoryItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = entry.id.uuidString
            historyMenu.addItem(item)
        }
    }

    private func rebuildAppDefaultsMenu() {
        appDefaultsMenu.removeAllItems()

        let currentAppName = PasteTargetDetector.currentExternalFrontmostApplication()?.localizedName ?? "Current App"
        let saveItem = NSMenuItem(title: "Save Defaults for \(currentAppName)", action: #selector(saveCurrentAppDefaults), keyEquivalent: "")
        saveItem.target = self
        appDefaultsMenu.addItem(saveItem)

        let clearItem = NSMenuItem(title: "Clear Defaults for \(currentAppName)", action: #selector(clearCurrentAppDefaults), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = AppDefaultsStore.defaultForCurrentApp() != nil
        appDefaultsMenu.addItem(clearItem)

        let defaults = AppDefaultsStore.all().values.sorted { $0.appName < $1.appName }
        guard !defaults.isEmpty else {
            return
        }

        appDefaultsMenu.addItem(NSMenuItem.separator())
        for appDefault in defaults {
            let profile = WritingProfile.choice(for: appDefault.writingProfileID)
            let language = OutputLanguage.choice(for: appDefault.outputLanguageID)
            let item = NSMenuItem(title: "\(appDefault.appName): \(profile.title) -> \(language.title)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            appDefaultsMenu.addItem(item)
        }
    }

    private func rebuildPreserveCapitalizationMenuItem() {
        preserveCapitalizationMenuItem.state = preserveCapitalization ? .on : .off
    }

    private func rebuildAudioDuckingMenuItem() {
        audioDuckingMenuItem.state = audioDuckingEnabled ? .on : .off
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
        updateCancelHotKey(for: newState)
        statusItem.button?.title = ""
        statusItem.button?.image = DuckIcon.menuBarImage()

        switch newState {
        case .ready, .error:
            recordingStartedAt = nil
            audioDucker.restore()
            stopRecordingLevelTimer()
            stopTranscriptionProgress()
            recordingOverlay.hide()
            toggleMenuItem.title = "Start Recording"
            toggleMenuItem.isEnabled = true
        case .recording:
            recordingOverlay.show(
                progressPercent: nil,
                statusText: "Recording",
                contextText: overlayContextText(),
                previewText: "",
                hintText: "Esc cancels"
            )
            startRecordingLevelTimer()
            toggleMenuItem.title = "Stop and Paste"
            toggleMenuItem.isEnabled = true
        case .transcribing:
            stopRecordingLevelTimer()
            recordingOverlay.show(
                progressPercent: transcriptionProgressPercent,
                statusText: "Transcribing",
                contextText: overlayContextText(),
                previewText: "Finalizing local transcript...",
                hintText: "Esc cancels"
            )
            toggleMenuItem.title = "Transcribing..."
            toggleMenuItem.isEnabled = false
        }

        copyLastMenuItem.isEnabled = !lastTranscript.isEmpty
        refreshPermissionUI()
        rebuildPreserveCapitalizationMenuItem()
        rebuildAudioDuckingMenuItem()
        rebuildProfileMenu()
        rebuildPerformanceMenu()
        rebuildHistoryMenu()
        rebuildAppDefaultsMenu()
    }

    private func updateCancelHotKey(for newState: AppState) {
        switch newState {
        case .recording, .transcribing:
            let status = hotKeyController.registerCancelHotKey()
            if status != noErr {
                AppLog.write("failed to register Escape cancel hotkey: \(status)")
            }
        case .ready, .error:
            hotKeyController.unregisterCancelHotKey()
        }
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshPermissionUI()
        }
    }

    private func startRecordingLevelTimer() {
        recordingLevelTimer?.invalidate()
        recordingLevelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else {
                return
            }
            self.recordingOverlay.setAudioLevel(self.audioCapture.currentLevel())
            let elapsed = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let preview = self.liveTranscriptionSession?.previewText() ?? ""
            self.recordingOverlay.setDetails(
                statusText: "Recording",
                contextText: self.overlayContextText(),
                previewText: preview,
                hintText: "Esc cancels • \(self.elapsedText(elapsed))"
            )
        }
    }

    private func stopRecordingLevelTimer() {
        recordingLevelTimer?.invalidate()
        recordingLevelTimer = nil
        recordingOverlay.setAudioLevel(0)
    }

    private func overlayContextText() -> String {
        let model = activeModelChoice ?? selectedModel
        let profile = activeWritingProfile ?? selectedWritingProfile
        let language = activeOutputLanguage ?? selectedOutputLanguage
        return "\(model.title) • \(profile.title) • \(language.title)"
    }

    private func elapsedText(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func refreshPermissionUI() {
        let hasAutoPastePermission = AXIsProcessTrusted()
        let permissionStatus = hasAutoPastePermission ? "Auto-Paste Permission Granted" : "Auto-Paste Permission Needed - Click to Fix"
        autoPastePermissionMenuItem.title = permissionStatus
        autoPastePermissionMenuItem.state = hasAutoPastePermission ? .on : .off
        autoPastePermissionMenuItem.toolTip = hasAutoPastePermission
            ? "DuckWhisperer can paste transcripts back into the target app."
            : "DuckWhisperer needs Accessibility permission to paste transcripts back into the target app."

        let permissionSuffix = hasAutoPastePermission ? "" : " - Auto-Paste Permission Needed"
        statusItem.button?.toolTip = "\(appDisplayName): \(state.statusText)\(permissionSuffix)"
        let formattingText = preserveCapitalization ? "Caps On" : "Caps Off"
        statusMenuItem.title = "\(state.statusText)\(permissionSuffix) - \(selectedModel.title) -> \(selectedOutputLanguage.title) - \(selectedWritingProfile.title) - \(formattingText)"
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

    @objc private func selectWritingProfile(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        UserDefaults.standard.set(WritingProfile.choice(for: id).id, forKey: selectedWritingProfileIDKey)
        rebuildProfileMenu()
        setState(.ready)
    }

    @objc private func selectPerformanceModel(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        useModel(ModelChoice.choice(for: id))
    }

    @objc private func togglePreserveCapitalization() {
        UserDefaults.standard.set(!preserveCapitalization, forKey: preserveCapitalizationKey)
        rebuildPreserveCapitalizationMenuItem()
        setState(state)
    }

    @objc private func toggleAudioDucking() {
        UserDefaults.standard.set(!audioDuckingEnabled, forKey: audioDuckingEnabledKey)
        rebuildAudioDuckingMenuItem()
        setState(state)
    }

    @objc private func openPersonalDictionary() {
        personalDictionaryController.show()
    }

    @objc private func openTranscriptHistory() {
        transcriptHistoryController.show()
    }

    @objc private func clearTranscriptHistory() {
        TranscriptHistoryStore.clear()
        rebuildHistoryMenu()
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let entry = TranscriptHistoryStore.entries().first(where: { $0.id.uuidString == id })
        else {
            return
        }
        copyToClipboard(entry.text)
        lastTranscript = entry.text
        copyLastMenuItem.isEnabled = true
    }

    @objc private func saveCurrentAppDefaults() {
        guard let appDefault = AppDefaultsStore.saveCurrentAppDefault(
            model: selectedModel,
            outputLanguage: selectedOutputLanguage,
            writingProfile: selectedWritingProfile
        ) else {
            NSSound.beep()
            return
        }
        AppLog.write("saved app defaults for \(appDefault.appName)")
        rebuildAppDefaultsMenu()
    }

    @objc private func clearCurrentAppDefaults() {
        guard let appDefault = AppDefaultsStore.clearCurrentAppDefault() else {
            NSSound.beep()
            return
        }
        AppLog.write("cleared app defaults for \(appDefault.appName)")
        rebuildAppDefaultsMenu()
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

    private func cancelActiveDictation() {
        switch state {
        case .recording:
            liveTranscriptionSession = nil
            pasteTarget = nil
            do {
                _ = try audioCapture.stop()
            } catch {
                AppLog.write("recording cancel stop failed: \(error.localizedDescription)")
            }
            recordingStartedAt = nil
            audioDucker.restore()
            AppLog.write("recording cancelled with Escape")
            setState(.ready)
        case .transcribing:
            activeTranscriptionID = nil
            liveTranscriptionSession = nil
            pasteTarget = nil
            stopTranscriptionProgress()
            audioDucker.restore()
            AppLog.write("transcription cancelled with Escape")
            setState(.ready)
        case .ready, .error:
            break
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
            activeAppName = pasteTarget?.application?.localizedName
            applyAppDefaultsIfAvailable(for: pasteTarget?.application)
            activeOutputLanguage = selectedOutputLanguage
            activeWritingProfile = selectedWritingProfile
            activeModelChoice = selectedModel
            try audioCapture.start()
            recordingStartedAt = Date()
            audioDucker.duckIfNeeded(enabled: audioDuckingEnabled)
            let session = LiveTranscriptionSession(audioCapture: audioCapture, transcriber: transcriber)
            liveTranscriptionSession = session
            session.start()
            setState(.recording)
        } catch {
            audioDucker.restore()
            setState(.error(error.localizedDescription))
            NSSound.beep()
        }
    }

    private func applyAppDefaultsIfAvailable(for application: NSRunningApplication?) {
        guard let appDefault = AppDefaultsStore.defaultFor(application) else {
            return
        }

        let model = ModelChoice.choice(for: appDefault.modelID)
        if let modelURL = ModelStore.installedURL(for: model) {
            UserDefaults.standard.set(model.id, forKey: selectedModelIDKey)
            transcriber.setModelURL(modelURL)
            rebuildModelMenu()
            rebuildPerformanceMenu()
        }

        UserDefaults.standard.set(OutputLanguage.choice(for: appDefault.outputLanguageID).id, forKey: selectedOutputLanguageIDKey)
        UserDefaults.standard.set(WritingProfile.choice(for: appDefault.writingProfileID).id, forKey: selectedWritingProfileIDKey)
        rebuildOutputMenu()
        rebuildProfileMenu()
        AppLog.write("applied app defaults for \(appDefault.appName)")
    }

    private func stopTranscribeAndPaste() {
        let samples: [Float]
        let liveSession = liveTranscriptionSession
        liveTranscriptionSession = nil

        do {
            samples = try audioCapture.stop()
        } catch {
            audioDucker.restore()
            setState(.error(error.localizedDescription))
            NSSound.beep()
            return
        }

        recordingStartedAt = nil
        audioDucker.restore()
        let transcriptionID = UUID()
        activeTranscriptionID = transcriptionID
        setState(.transcribing)
        startTranscriptionProgress(audioDuration: Double(samples.count) / Double(WHISPER_SAMPLE_RATE))
        let outputLanguage = activeOutputLanguage ?? selectedOutputLanguage
        let writingProfile = activeWritingProfile ?? selectedWritingProfile
        let modelChoice = activeModelChoice ?? selectedModel
        let appName = activeAppName
        let shouldPreserveCapitalization = preserveCapitalization
        let dictionaryEntries = personalDictionaryEntries

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let startedAt = Date()
                let transcript = try liveSession?.finish(with: samples)
                    ?? self.transcriber.transcribe(samples: samples)
                let commandResult = CommandPhraseProcessor.process(
                    transcript,
                    outputLanguage: outputLanguage,
                    writingProfile: writingProfile
                )
                let dictionaryOutput = PersonalDictionary.apply(dictionaryEntries, to: commandResult.text)
                let translatedOutput: String
                do {
                    translatedOutput = try LocalTranslator.translate(dictionaryOutput, to: commandResult.outputLanguage)
                } catch {
                    AppLog.write("translation failed for \(commandResult.outputLanguage.title); falling back to English transcript: \(error.localizedDescription)")
                    translatedOutput = dictionaryOutput
                }
                let languageOutput = self.applyLanguageOutput(to: translatedOutput, outputLanguage: commandResult.outputLanguage)
                let profileOutput = WritingProfileRenderer.render(languageOutput, profile: commandResult.writingProfile)
                let output = self.applyOutputFormatting(
                    to: profileOutput,
                    preserveCapitalization: shouldPreserveCapitalization
                )
                let elapsed = Date().timeIntervalSince(startedAt)

                DispatchQueue.main.async {
                    guard self.isActiveTranscription(transcriptionID) else {
                        AppLog.write("ignored transcription result after cancellation")
                        return
                    }
                    self.completeTranscriptionProgress()
                    self.recordingOverlay.show(
                        progressPercent: 100,
                        statusText: "Pasting",
                        contextText: self.overlayContextText(),
                        previewText: output,
                        hintText: "Copied to clipboard"
                    )
                    AppLog.write(String(format: "transcribed %.2fs of audio in %.2fs", Double(samples.count) / Double(WHISPER_SAMPLE_RATE), elapsed))
                    if let commandName = commandResult.commandName {
                        AppLog.write("command phrase applied: \(commandName)")
                    }
                    self.lastTranscript = output
                    self.copyToClipboard(output)
                    TranscriptHistoryStore.add(
                        text: output,
                        appName: appName,
                        model: modelChoice,
                        outputLanguage: commandResult.outputLanguage,
                        writingProfile: commandResult.writingProfile
                    )
                    self.rebuildHistoryMenu()
                    self.deliverTranscript(output, transcriptionID: transcriptionID)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.isActiveTranscription(transcriptionID) else {
                        AppLog.write("ignored transcription error after cancellation")
                        return
                    }
                    self.finishActiveTranscription(transcriptionID)
                    self.stopTranscriptionProgress()
                    self.setState(.error(error.localizedDescription))
                    NSSound.beep()
                }
            }
        }
    }

    private func isActiveTranscription(_ transcriptionID: UUID?) -> Bool {
        guard let transcriptionID else {
            return true
        }
        return activeTranscriptionID == transcriptionID
    }

    private func finishActiveTranscription(_ transcriptionID: UUID?) {
        guard let transcriptionID else {
            return
        }
        if activeTranscriptionID == transcriptionID {
            activeTranscriptionID = nil
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
        guard text.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else {
            return text
        }

        switch outputLanguage.id {
        case "british":
            return StyledSpeech.british(text)
        case "genz":
            return StyledSpeech.genZ(text)
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

    private func deliverTranscript(_ output: String, transcriptionID: UUID? = nil) {
        guard isActiveTranscription(transcriptionID) else {
            AppLog.write("delivery skipped after cancellation")
            return
        }

        let target = pasteTarget
        pasteTarget = nil

        guard AXIsProcessTrusted() else {
            AppLog.write("delivery fallback; Accessibility not trusted, transcript copied and transcript window shown")
            transcriptionResult.show(text: output)
            finishActiveTranscription(transcriptionID)
            setState(.ready)
            return
        }

        let finish: (_ allowFocusedCheckBypass: Bool) -> Void = { [weak self] allowFocusedCheckBypass in
            guard let self else { return }
            guard self.isActiveTranscription(transcriptionID) else {
                AppLog.write("delivery finish skipped after cancellation")
                return
            }
            if !self.pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: allowFocusedCheckBypass) {
                self.transcriptionResult.show(text: output)
            }
            self.finishActiveTranscription(transcriptionID)
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
                guard self.isActiveTranscription(transcriptionID) else {
                    AppLog.write("blind paste skipped after cancellation")
                    return
                }
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.finishActiveTranscription(transcriptionID)
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
            guard self.isActiveTranscription(transcriptionID) else {
                AppLog.write("focus restore skipped after cancellation")
                return
            }
            let restoredFocus = PasteTargetDetector.focusCapturedTarget(target)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard self.isActiveTranscription(transcriptionID) else {
                    AppLog.write("focused paste skipped after cancellation")
                    return
                }
                if self.shouldUseSyntheticTyping(for: target),
                   self.typeTextWithKeyboard(output) {
                    self.finishActiveTranscription(transcriptionID)
                    self.setState(.ready)
                    return
                }
                if PasteTargetDetector.insertTextDirectly(output, into: target) {
                    self.finishActiveTranscription(transcriptionID)
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

    @objc private func openSetupDoctor() {
        showSetupDoctor()
    }

    private func showSetupDoctor() {
        setupDoctorController.show()
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
