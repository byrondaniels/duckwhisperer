import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import whisper

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let modelMenu = NSMenu()
    private let inputLanguageMenu = NSMenu()
    private let outputMenu = NSMenu()
    private let styleIntensityMenu = NSMenu()
    private let profileMenu = NSMenu()
    private let performanceMenu = NSMenu()
    private let historyMenu = NSMenu()
    private let appDefaultsMenu = NSMenu()
    private let settingsMenu = NSMenu()
    private let recordShortcutMenu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Starting...", action: nil, keyEquivalent: "")
    private let autoPastePermissionMenuItem = NSMenuItem(title: "Paste-Back: Checking...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let privacyMenuItem = NSMenuItem(title: "Private: your voice stays on this Mac", action: nil, keyEquivalent: "")
    private let timeSavedMenuItem = NSMenuItem(title: "Time Saved: 0s typing", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Voice Typing", action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
    private let undoLastPasteMenuItem = NSMenuItem(title: "Undo Last Paste", action: #selector(undoLastPaste), keyEquivalent: "")
    private let copyLastMenuItem = NSMenuItem(title: "Copy Last Text", action: #selector(copyLastTranscript), keyEquivalent: "")
    private let preserveCapitalizationMenuItem = NSMenuItem(title: "Preserve Capitalization", action: #selector(togglePreserveCapitalization), keyEquivalent: "")
    private let audioDuckingMenuItem = NSMenuItem(title: "Audio Ducking", action: #selector(toggleAudioDucking), keyEquivalent: "")
    private let presenterModeMenuItem = NSMenuItem(title: "Presenter Mode", action: #selector(togglePresenterMode), keyEquivalent: "")
    private let hotKeyController = HotKeyController()
    private let audioCapture = AudioCapture()
    private let audioDucker = AudioDucker()
    private let recordingOverlay = RecordingOverlayController()
    private lazy var transcriptionResult = TranscriptionResultController(
        onPasteAgain: { [weak self] text in
            self?.retryPaste(text)
        },
        onFixPermission: { [weak self] in
            self?.openAccessibilitySettings()
        },
        onTryHere: { [weak self] text in
            self?.openTryItWithRecoveredText(text)
        }
    )
    private lazy var tryItController = TryItController()
    private lazy var personalDictionaryController = PersonalDictionaryController { [weak self] in
        self?.refreshPermissionUI()
    }
    private lazy var transcriptHistoryController = TranscriptHistoryController()
    private lazy var setupDoctorController = SetupDoctorController(
        onOpenMicrophone: { [weak self] in self?.openMicrophoneSettings() },
        onOpenAccessibility: { [weak self] in self?.openAccessibilitySettings() },
        onOpenModelExplorer: { [weak self] in self?.showModelExplorer() },
        onDownloadDefaultModel: { [weak self] in
            self?.downloadDefaultModelForSetup()
        },
        onOpenTryIt: { [weak self] in self?.openTryIt() },
        onExportSupportBundle: { [weak self] in self?.exportSupportBundle() }
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
    private var lastRecordingDetailsRefreshAt: Date?
    private var activeAppName: String?
    private var activeInputLanguage: InputLanguageChoice?
    private var activeOutputLanguage: OutputLanguage?
    private var activeWritingProfile: WritingProfile?
    private var activeModelChoice: ModelChoice?
    private var activeCommandName: String?
    private var lastUndoTarget: PasteTarget?
    private var canUndoLastPaste = false
    private var lastPasteWasTryIt = false
    private var downloadingSpeechModelKeys = Set<String>()
    private var installingTranslationPackIDs = Set<String>()
    private var workingStatusText: String?
    private var workingIndicatorTimer: Timer?
    private var workingIndicatorFrame = 0

    private var selectedModel: ModelChoice {
        ModelChoice.choice(for: UserDefaults.standard.string(forKey: selectedModelIDKey))
    }

    private var selectedInputLanguage: InputLanguageChoice {
        InputLanguageChoice.choice(for: UserDefaults.standard.string(forKey: selectedInputLanguageIDKey))
    }

    private var selectedOutputLanguage: OutputLanguage {
        OutputLanguage.choice(for: UserDefaults.standard.string(forKey: selectedOutputLanguageIDKey))
    }

    private var selectedStyleIntensity: StyleIntensityChoice {
        let stored = UserDefaults.standard.object(forKey: selectedStyleIntensityPercentKey) as? Int
        return StyleIntensityChoice.choice(for: stored)
    }

    private var selectedWritingProfile: WritingProfile {
        WritingProfile.choice(for: UserDefaults.standard.string(forKey: selectedWritingProfileIDKey))
    }

    private var audioDuckingEnabled: Bool {
        UserDefaults.standard.bool(forKey: audioDuckingEnabledKey)
    }

    private var presenterModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: presenterModeEnabledKey)
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
        ModelStore.installedURL(for: selectedModel, inputLanguage: selectedInputLanguage)
            ?? ModelStore.installedURL(for: selectedModel)
            ?? ModelStore.installedURL(for: ModelChoice.defaultChoice)
            ?? ModelStore.bundledURL(for: ModelChoice.defaultChoice)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installApplicationIcon()
        AppLog.write("launched; axTrusted=\(AXIsProcessTrusted())")

        setupMenu()
        transcriber.setLanguageCode(selectedInputLanguage.whisperCode)
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
            if ModelStore.isInstalled(selectedModel, inputLanguage: selectedInputLanguage) {
                setState(.ready)
                preloadModel()
            } else {
                setState(.error("Choose Input Language or Speed & Accuracy to download speech support."))
            }
        } else {
            setState(.error(DuckWhispererError.hotKeyFailed(hotKeyStatus).localizedDescription))
        }

        if CommandLine.arguments.contains("--open-model-explorer") {
            showModelExplorer()
        }

        if !isSetupComplete() || !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) {
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetupDoctor()
        return true
    }

    private func isSetupComplete() -> Bool {
        let modelReady = ModelStore.isInstalled(ModelChoice.defaultChoice)
        let micReady = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let pasteReady = PasteTargetDetector.readiness().severity != .blocked
        return modelReady && micReady && pasteReady
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
        menu.delegate = self
        statusItem.button?.title = ""
        statusItem.button?.image = DuckWhispererIcon.menuBarImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = appDisplayName
        statusMenuItem.isEnabled = false
        privacyMenuItem.isEnabled = false
        timeSavedMenuItem.isEnabled = false
        autoPastePermissionMenuItem.target = self
        autoPastePermissionMenuItem.action = #selector(openSetupDoctor)
        toggleMenuItem.target = self
        undoLastPasteMenuItem.target = self
        undoLastPasteMenuItem.isEnabled = false
        copyLastMenuItem.target = self
        copyLastMenuItem.isEnabled = false
        preserveCapitalizationMenuItem.target = self
        audioDuckingMenuItem.target = self
        presenterModeMenuItem.target = self

        let openMicSettings = NSMenuItem(
            title: "Open Microphone Settings",
            action: #selector(openMicrophoneSettings),
            keyEquivalent: ""
        )
        openMicSettings.target = self

        let openAccessibilitySettings = NSMenuItem(
            title: "Open Paste-Back Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        openAccessibilitySettings.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(privacyMenuItem)
        menu.addItem(timeSavedMenuItem)
        menu.addItem(autoPastePermissionMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleMenuItem)
        let tryItItem = NSMenuItem(title: "Try It Here...", action: #selector(openTryIt), keyEquivalent: "")
        tryItItem.target = self
        menu.addItem(tryItItem)
        menu.addItem(undoLastPasteMenuItem)
        menu.addItem(copyLastMenuItem)
        menu.addItem(profileMenuItem())
        menu.addItem(inputLanguageMenuItem())
        menu.addItem(outputMenuItem())
        menu.addItem(styleIntensityMenuItem())
        menu.addItem(performanceMenuItem())
        menu.addItem(recordShortcutMenuItem())
        menu.addItem(preserveCapitalizationMenuItem)
        let personalDictionaryItem = NSMenuItem(
            title: "Saved Words...",
            action: #selector(openPersonalDictionary),
            keyEquivalent: ""
        )
        personalDictionaryItem.target = self
        menu.addItem(personalDictionaryItem)
        menu.addItem(historyMenuItem())

        let userGuideItem = NSMenuItem(
            title: "Open User Guide...",
            action: #selector(openUserGuide),
            keyEquivalent: ""
        )
        userGuideItem.target = self
        let setupDoctorItem = NSMenuItem(
            title: "Finish Setup...",
            action: #selector(openSetupDoctor),
            keyEquivalent: ""
        )
        setupDoctorItem.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(setupDoctorItem)
        menu.addItem(settingsMenuItem())

        settingsMenu.addItem(appDefaultsMenuItem())
        settingsMenu.addItem(audioDuckingMenuItem)
        settingsMenu.addItem(presenterModeMenuItem)
        settingsMenu.addItem(NSMenuItem.separator())
        let topLevelModelExplorer = NSMenuItem(
            title: "Open Speed & Accuracy...",
            action: #selector(openModelExplorer(_:)),
            keyEquivalent: ""
        )
        topLevelModelExplorer.target = self
        settingsMenu.addItem(topLevelModelExplorer)
        settingsMenu.addItem(modelMenuItem())
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(userGuideItem)
        let exportSupportItem = NSMenuItem(
            title: "Export Support Bundle...",
            action: #selector(exportSupportBundle),
            keyEquivalent: ""
        )
        exportSupportItem.target = self
        settingsMenu.addItem(exportSupportItem)
        let checkForUpdatesItem = NSMenuItem(
            title: "Check For Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        settingsMenu.addItem(checkForUpdatesItem)
        settingsMenu.addItem(openMicSettings)
        settingsMenu.addItem(openAccessibilitySettings)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit \(appDisplayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        rebuildPreserveCapitalizationMenuItem()
        rebuildAudioDuckingMenuItem()
        rebuildPresenterModeMenuItem()
        rebuildInputLanguageMenu()
        rebuildOutputMenu()
        rebuildStyleIntensityMenu()
        rebuildProfileMenu()
        rebuildPerformanceMenu()
        rebuildHistoryMenu()
        rebuildAppDefaultsMenu()
        rebuildModelMenu()
        rebuildRecordShortcutMenu()
        refreshPermissionUI()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionUI()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === autoPastePermissionMenuItem {
            return true
        }
        if menuItem === undoLastPasteMenuItem {
            return canUndoLastPaste
        }
        if menuItem === copyLastMenuItem {
            return !lastTranscript.isEmpty
        }
        if menuItem === toggleMenuItem {
            return state != .transcribing
        }
        return menuItem.isEnabled
    }

    private func inputLanguageMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Input Language", action: nil, keyEquivalent: "")
        item.submenu = inputLanguageMenu
        return item
    }

    private func outputMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Output Language", action: nil, keyEquivalent: "")
        item.submenu = outputMenu
        return item
    }

    private func styleIntensityMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Style Intensity", action: nil, keyEquivalent: "")
        item.submenu = styleIntensityMenu
        return item
    }

    private func profileMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Writing Mode", action: nil, keyEquivalent: "")
        item.submenu = profileMenu
        return item
    }

    private func performanceMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Speed & Accuracy", action: nil, keyEquivalent: "")
        item.submenu = performanceMenu
        return item
    }

    private func historyMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        item.submenu = historyMenu
        return item
    }

    private func appDefaultsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "App Defaults", action: nil, keyEquivalent: "")
        item.submenu = appDefaultsMenu
        return item
    }

    private func modelMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Model Downloads", action: nil, keyEquivalent: "")
        item.submenu = modelMenu
        return item
    }

    private func settingsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        item.submenu = settingsMenu
        return item
    }

    private func recordShortcutMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Recording Shortcut", action: nil, keyEquivalent: "")
        item.submenu = recordShortcutMenu
        return item
    }

    private func rebuildRecordShortcutMenu() {
        recordShortcutMenu.removeAllItems()
        let current = RecordShortcutPreset.currentSelected
        for preset in RecordShortcutPreset.all {
            let item = NSMenuItem(title: preset.title, action: #selector(selectRecordShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            item.state = preset == current ? .on : .off
            recordShortcutMenu.addItem(item)
        }
    }

    @objc private func selectRecordShortcut(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }
        guard let id = sender.representedObject as? String else { return }
        let preset = RecordShortcutPreset.preset(for: id)
        UserDefaults.standard.set(preset.id, forKey: recordShortcutPresetIDKey)
        let status = hotKeyController.reregisterRecordHotKey(preset: preset)
        if status != noErr {
            AppLog.write("failed to re-register record hotkey \(preset.id): \(status)")
            NSSound.beep()
        }
        rebuildRecordShortcutMenu()
    }

    private func rebuildInputLanguageMenu() {
        inputLanguageMenu.removeAllItems()
        let current = selectedInputLanguage
        let model = selectedModel

        for (index, language) in InputLanguageChoice.all.enumerated() {
            if index == 1 {
                inputLanguageMenu.addItem(NSMenuItem.separator())
                let noteItem = NSMenuItem(title: "Non-English uses one shared multilingual model", action: nil, keyEquivalent: "")
                noteItem.isEnabled = false
                inputLanguageMenu.addItem(noteItem)
            }
            let asset = model.asset(for: language)
            let installed = ModelStore.isInstalled(model, inputLanguage: language)
            let suffix: String
            if downloadingSpeechModelKeys.contains(asset.filename) {
                suffix = language.isEnglish ? " - downloading..." : " - downloading shared model..."
            } else {
                suffix = installed ? "" : (language.isEnglish ? " - needs download" : " - needs shared download")
            }
            let item = NSMenuItem(title: "\(language.title)\(suffix)", action: #selector(selectInputLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.id
            item.state = language == current ? .on : .off
            item.isEnabled = !downloadingSpeechModelKeys.contains(asset.filename)
            inputLanguageMenu.addItem(item)
        }
    }

    private func rebuildOutputMenu() {
        outputMenu.removeAllItems()
        let current = selectedOutputLanguage
        let inputLanguage = selectedInputLanguage
        var insertedStyleSeparator = false

        for language in OutputLanguage.all {
            if !language.isSameAsInput, language.languageCode == inputLanguage.whisperCode {
                continue
            }
            if !insertedStyleSeparator, !language.isSameAsInput, language.languageCode == nil {
                outputMenu.addItem(NSMenuItem.separator())
                insertedStyleSeparator = true
            }
            let title = language.isSameAsInput
                ? "Same as Input (\(inputLanguage.title))"
                : language.title
            let requiredTranslationPacks = TranscriptionOutputPipeline
                .requiredTranslationPacks(inputLanguage: inputLanguage, outputLanguage: language)
            let missingTranslationPacks = requiredTranslationPacks.filter { !TranslationStore.isInstalled($0) }
            let isInstallingTranslator = requiredTranslationPacks.contains { installingTranslationPackIDs.contains($0.id) }
            let translationSuffix = isInstallingTranslator
                ? " - installing translator..."
                : (missingTranslationPacks.isEmpty ? "" : " - needs translator")
            let item = NSMenuItem(title: "\(title)\(translationSuffix)", action: #selector(selectOutputLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.id
            item.state = language == current || (language.isSameAsInput && current.matchesInput(inputLanguage)) ? .on : .off
            outputMenu.addItem(item)
        }
    }

    private func rebuildStyleIntensityMenu() {
        styleIntensityMenu.removeAllItems()
        let current = selectedStyleIntensity

        for choice in StyleIntensityChoice.all {
            let item = NSMenuItem(title: choice.title, action: #selector(selectStyleIntensity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.percent
            item.state = choice == current ? .on : .off
            item.toolTip = choice.detail
            styleIntensityMenu.addItem(item)
        }
    }

    private func rebuildProfileMenu() {
        profileMenu.removeAllItems()
        let current = selectedWritingProfile

        for profile in WritingProfile.all {
            let item = NSMenuItem(title: profile.title, action: #selector(selectWritingProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id
            item.state = profile == current ? .on : .off
            item.toolTip = profile.detail
            profileMenu.addItem(item)
        }
    }

    private func rebuildPerformanceMenu() {
        performanceMenu.removeAllItems()
        let inputLanguage = selectedInputLanguage
        let mappings: [(title: String, model: ModelChoice)] = [
            (ModelChoice.choice(for: "tiny-en").friendlyMenuTitle, ModelChoice.choice(for: "tiny-en")),
            (ModelChoice.choice(for: "base-en").friendlyMenuTitle, ModelChoice.choice(for: "base-en")),
            (ModelChoice.choice(for: "small-en").friendlyMenuTitle, ModelChoice.choice(for: "small-en"))
        ]

        for mapping in mappings {
            let installed = ModelStore.isInstalled(mapping.model, inputLanguage: inputLanguage)
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

        historyMenu.addItem(NSMenuItem.separator())
        let stats = DictationStatsStore.current()
        let statsItem = NSMenuItem(title: stats.menuSummary, action: nil, keyEquivalent: "")
        statsItem.isEnabled = false
        historyMenu.addItem(statsItem)
        let detailItem = NSMenuItem(title: stats.detailSummary, action: nil, keyEquivalent: "")
        detailItem.isEnabled = false
        historyMenu.addItem(detailItem)

        let entries = TranscriptHistoryStore.entries().prefix(6)
        guard !entries.isEmpty else {
            historyMenu.addItem(NSMenuItem.separator())
            let emptyItem = NSMenuItem(title: "No transcripts yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
            addHistoryMaintenanceItems()
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
        addHistoryMaintenanceItems()
    }

    private func addHistoryMaintenanceItems() {
        historyMenu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearTranscriptHistory), keyEquivalent: "")
        clearItem.target = self
        historyMenu.addItem(clearItem)
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

    private func rebuildPresenterModeMenuItem() {
        presenterModeMenuItem.state = presenterModeEnabled ? .on : .off
        recordingOverlay.setPresenterMode(presenterModeEnabled)
    }

    private func rebuildModelMenu() {
        modelMenu.removeAllItems()
        let current = selectedModel
        let inputLanguage = selectedInputLanguage

        let explorerItem = NSMenuItem(title: "Open Speed & Accuracy...", action: #selector(openModelExplorer(_:)), keyEquivalent: "")
        explorerItem.target = self
        modelMenu.addItem(explorerItem)
        modelMenu.addItem(NSMenuItem.separator())

        for choice in ModelChoice.all {
            let exists = ModelStore.isInstalled(choice, inputLanguage: inputLanguage)
            let title = exists
                ? "\(choice.friendlyMenuTitle) - \(choice.friendlyDetail)"
                : "\(choice.friendlyMenuTitle) - not installed"
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
    }

    private func setState(_ newState: AppState) {
        state = newState
        updateCancelHotKey(for: newState)
        statusItem.button?.title = ""
        statusItem.button?.image = DuckWhispererIcon.menuBarImage()

        switch newState {
        case .ready, .error:
            recordingStartedAt = nil
            lastRecordingDetailsRefreshAt = nil
            audioDucker.restore()
            stopRecordingLevelTimer()
            stopTranscriptionProgress()
            recordingOverlay.hide()
            toggleMenuItem.title = "Start Voice Typing"
            toggleMenuItem.isEnabled = true
        case .recording:
            recordingOverlay.show(
                progressPercent: nil,
                statusText: "Recording",
                contextText: overlayContextText(),
                previewText: "",
                hintText: "Esc cancels",
                commandText: activeCommandName,
                presenterMode: presenterModeEnabled
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
                hintText: "Esc cancels",
                commandText: activeCommandName,
                presenterMode: presenterModeEnabled
            )
            toggleMenuItem.title = "Transcribing..."
            toggleMenuItem.isEnabled = false
        }

        copyLastMenuItem.isEnabled = !lastTranscript.isEmpty
        undoLastPasteMenuItem.isEnabled = canUndoLastPaste
        refreshPermissionUI()
        rebuildPreserveCapitalizationMenuItem()
        rebuildAudioDuckingMenuItem()
        rebuildPresenterModeMenuItem()
        rebuildInputLanguageMenu()
        rebuildOutputMenu()
        rebuildStyleIntensityMenu()
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
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else {
                return
            }
            self.recordingOverlay.setAudioLevel(self.audioCapture.currentLevel())

            let now = Date()
            if let lastRecordingDetailsRefreshAt = self.lastRecordingDetailsRefreshAt,
               now.timeIntervalSince(lastRecordingDetailsRefreshAt) < 0.16 {
                return
            }
            self.lastRecordingDetailsRefreshAt = now

            let elapsed = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let preview = self.liveTranscriptionSession?.previewText() ?? ""
            if let detectedCommandName = CommandPhraseProcessor.detectedCommandName(in: preview) {
                self.activeCommandName = detectedCommandName
            }
            self.recordingOverlay.setDetails(
                statusText: "Recording",
                contextText: self.overlayContextText(),
                previewText: preview,
                hintText: "Esc cancels • \(self.elapsedText(elapsed))",
                commandText: self.activeCommandName,
                presenterMode: self.presenterModeEnabled
            )
        }
        recordingLevelTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopRecordingLevelTimer() {
        recordingLevelTimer?.invalidate()
        recordingLevelTimer = nil
        lastRecordingDetailsRefreshAt = nil
        recordingOverlay.setAudioLevel(0)
    }

    private func overlayContextText() -> String {
        let inputLanguage = activeInputLanguage ?? selectedInputLanguage
        let language = activeOutputLanguage ?? selectedOutputLanguage
        return overlayLanguageRouteText(inputLanguage: inputLanguage, outputLanguage: language)
    }

    private func elapsedText(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func refreshPermissionUI() {
        let pasteReadiness = PasteTargetDetector.readiness()
        let hasAutoPastePermission = pasteReadiness.severity != .blocked
        autoPastePermissionMenuItem.title = pasteReadiness.menuTitle
        autoPastePermissionMenuItem.state = .off
        autoPastePermissionMenuItem.isEnabled = true
        autoPastePermissionMenuItem.target = self
        autoPastePermissionMenuItem.action = #selector(openSetupDoctor)
        autoPastePermissionMenuItem.toolTip = pasteReadiness.detail

        timeSavedMenuItem.title = DictationStatsStore.current().menuSummary

        let permissionSuffix = hasAutoPastePermission ? "" : " - Paste-Back Needs Permission"
        statusItem.button?.toolTip = "\(appDisplayName): \(workingStatusText ?? state.statusText)\(permissionSuffix)"
        let routeText = overlayLanguageRouteText(inputLanguage: selectedInputLanguage, outputLanguage: selectedOutputLanguage)
        let routeSuffix = routeText.isEmpty ? "" : " - \(routeText)"
        let formattingSuffix = preserveCapitalization ? "" : " - Lowercase Mode"
        statusMenuItem.title = "\(plainStatusText())\(permissionSuffix)\(routeSuffix)\(formattingSuffix)"
    }

    private func plainStatusText() -> String {
        if let workingStatusText {
            return workingStatusText
        }
        switch state {
        case .ready:
            return "Ready - Voice Typing"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .error(let message):
            return "Needs Attention - \(message)"
        }
    }

    private func beginWorking(_ statusText: String) {
        workingStatusText = statusText
        workingIndicatorFrame = 0
        workingIndicatorTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.advanceWorkingIndicator()
        }
        workingIndicatorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        advanceWorkingIndicator()
        refreshPermissionUI()
    }

    private func endWorking() {
        workingStatusText = nil
        workingIndicatorTimer?.invalidate()
        workingIndicatorTimer = nil
        if let button = statusItem.button {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        refreshPermissionUI()
    }

    private func advanceWorkingIndicator() {
        guard let button = statusItem.button, workingStatusText != nil else {
            return
        }
        let dots = String(repeating: "•", count: workingIndicatorFrame % 3 + 1)
        button.imagePosition = .imageLeading
        button.title = " \(dots)"
        workingIndicatorFrame += 1
    }

    private func languageRouteText(inputLanguage: InputLanguageChoice, outputLanguage: OutputLanguage) -> String {
        let outputTitle = outputLanguage.effectiveTitle(for: inputLanguage)
        if outputTitle == inputLanguage.title {
            return "Speak \(inputLanguage.title)"
        }
        return "Speak \(inputLanguage.title) -> \(outputTitle)"
    }

    private func overlayLanguageRouteText(inputLanguage: InputLanguageChoice, outputLanguage: OutputLanguage) -> String {
        let outputTitle = outputLanguage.effectiveTitle(for: inputLanguage)
        guard !(inputLanguage.isEnglish && outputTitle == "English") else {
            return ""
        }
        return "\(inputLanguage.title) speech -> \(outputTitle) text"
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

        let inputLanguage = selectedInputLanguage
        guard let modelURL = ModelStore.installedURL(for: choice, inputLanguage: inputLanguage) else {
            showModelExplorer()
            return
        }

        UserDefaults.standard.set(choice.id, forKey: selectedModelIDKey)
        transcriber.setLanguageCode(inputLanguage.whisperCode)
        transcriber.setModelURL(modelURL)
        rebuildInputLanguageMenu()
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel, inputLanguage: selectedInputLanguage)
        setState(.ready)
        preloadModel()
    }

    private func handleModelsChanged() {
        let inputLanguage = selectedInputLanguage
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel, inputLanguage: inputLanguage)
        if ModelStore.isInstalled(selectedModel, inputLanguage: inputLanguage) {
            setState(.ready)
            preloadModel()
        } else {
            setState(state)
        }
    }

    @objc private func selectInputLanguage(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let id = sender.representedObject as? String else {
            return
        }

        let language = InputLanguageChoice.choice(for: id)
        ensureSpeechModel(for: selectedModel, inputLanguage: language) { [weak self] in
            self?.applyInputLanguage(language)
        }
    }

    private func applyInputLanguage(_ language: InputLanguageChoice) {
        guard let modelURL = ModelStore.installedURL(for: selectedModel, inputLanguage: language) else {
            setState(.error("Download \(language.title) input support before recording."))
            NSSound.beep()
            return
        }

        UserDefaults.standard.set(language.id, forKey: selectedInputLanguageIDKey)
        transcriber.setLanguageCode(language.whisperCode)
        transcriber.setModelURL(modelURL)
        rebuildInputLanguageMenu()
        rebuildPerformanceMenu()
        rebuildModelMenu()
        modelExplorer.refresh(currentModel: selectedModel, inputLanguage: language)
        setState(.ready)
        preloadModel()
    }

    private func ensureSpeechModel(
        for choice: ModelChoice,
        inputLanguage: InputLanguageChoice,
        onDownloadStateChange: ((Bool) -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        if ModelStore.isInstalled(choice, inputLanguage: inputLanguage) {
            completion()
            return
        }

        let asset = choice.asset(for: inputLanguage)
        let key = asset.filename
        guard !downloadingSpeechModelKeys.contains(key) else {
            NSSound.beep()
            return
        }

        let alert = NSAlert()
        alert.messageText = inputLanguage.isEnglish ? "Download English Speech?" : "Download Multilingual Speech?"
        let unlockText = inputLanguage.isEnglish
            ? "This installs \(asset.filename), the English-only Whisper file for \(choice.friendlyTitle)."
            : "\(inputLanguage.title) uses \(asset.filename), one shared multilingual Whisper file for \(choice.friendlyTitle). It unlocks all non-English input choices for this speed; DuckWhisperer is not downloading a separate pack for each language."
        alert.informativeText = "\(unlockText) Download size: \(asset.downloadSizeText). Nothing downloads unless you choose Download."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            rebuildInputLanguageMenu()
            return
        }

        downloadingSpeechModelKeys.insert(key)
        onDownloadStateChange?(true)
        let downloadStatus = inputLanguage.isEnglish ? "Downloading English speech..." : "Downloading multilingual speech..."
        beginWorking(downloadStatus)

        URLSession.shared.downloadTask(with: choice.downloadURL(for: inputLanguage)) { [weak self] temporaryURL, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.downloadingSpeechModelKeys.remove(key)
                onDownloadStateChange?(false)

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
                    completion()
                } catch {
                    self.setState(.error(error.localizedDescription))
                    NSSound.beep()
                }

                self.endWorking()
                self.rebuildInputLanguageMenu()
                self.rebuildPerformanceMenu()
                self.rebuildModelMenu()
            }
        }.resume()
    }

    private func ensureTranslationPacks(
        inputLanguage: InputLanguageChoice,
        outputLanguage: OutputLanguage,
        completion: @escaping () -> Void
    ) {
        let missingPacks = TranscriptionOutputPipeline
            .requiredTranslationPacks(inputLanguage: inputLanguage, outputLanguage: outputLanguage)
            .filter { !TranslationStore.isInstalled($0) }

        guard let pack = missingPacks.first else {
            completion()
            return
        }

        confirmAndInstallTranslationPack(pack) { [weak self] installed in
            guard let self else { return }
            if installed {
                self.ensureTranslationPacks(
                    inputLanguage: inputLanguage,
                    outputLanguage: outputLanguage,
                    completion: completion
                )
            } else {
                self.rebuildOutputMenu()
                self.modelExplorer.refresh(currentModel: self.selectedModel, inputLanguage: self.selectedInputLanguage)
            }
        }
    }

    private func confirmAndInstallTranslationPack(
        _ pack: TranslationPackChoice,
        completion: @escaping (Bool) -> Void
    ) {
        guard !installingTranslationPackIDs.contains(pack.id) else {
            NSSound.beep()
            completion(false)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Install \(pack.title)?"
        let runtimeNote: String
        switch pack.backend {
        case .argos:
            runtimeNote = "This installs one local Argos translation package."
        case .huggingFaceMarian(_):
            runtimeNote = "This installs one dedicated Helsinki/OPUS text translator. The first dedicated translator may also install a local Python ML runtime."
        }
        alert.informativeText = "\(runtimeNote) Download size: \(pack.downloadSizeText). Nothing downloads unless you choose Install."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            completion(false)
            return
        }

        installingTranslationPackIDs.insert(pack.id)
        beginWorking("Installing \(pack.title)...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try TranslationStore.install(pack)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.installingTranslationPackIDs.remove(pack.id)
                    self.endWorking()
                    self.rebuildOutputMenu()
                    self.modelExplorer.refresh(currentModel: self.selectedModel, inputLanguage: self.selectedInputLanguage)
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.installingTranslationPackIDs.remove(pack.id)
                    self.endWorking()
                    self.setState(.error(error.localizedDescription))
                    NSSound.beep()
                    completion(false)
                }
            }
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
        ensureTranslationPacks(inputLanguage: selectedInputLanguage, outputLanguage: language) { [weak self] in
            self?.setSelectedOutputLanguage(language)
        }
    }

    private func setSelectedOutputLanguage(_ language: OutputLanguage) {
        UserDefaults.standard.set(language.id, forKey: selectedOutputLanguageIDKey)
        rebuildOutputMenu()
        setState(.ready)
    }

    @objc private func selectStyleIntensity(_ sender: NSMenuItem) {
        guard state != .recording, state != .transcribing else {
            NSSound.beep()
            return
        }

        guard let percent = sender.representedObject as? Int else {
            return
        }

        UserDefaults.standard.set(StyleIntensityChoice.choice(for: percent).percent, forKey: selectedStyleIntensityPercentKey)
        rebuildStyleIntensityMenu()
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

    @objc private func togglePresenterMode() {
        UserDefaults.standard.set(!presenterModeEnabled, forKey: presenterModeEnabledKey)
        rebuildPresenterModeMenuItem()
        setState(state)
    }

    @objc private func openTryIt() {
        tryItController.show()
    }

    private func openTryItWithRecoveredText(_ text: String) {
        tryItController.show(withRecoveredText: text)
    }

    @objc private func openPersonalDictionary() {
        personalDictionaryController.show()
    }

    @objc private func openTranscriptHistory() {
        transcriptHistoryController.show()
    }

    @objc private func openUserGuide() {
        guard let url = Bundle.main.url(forResource: "UserGuide", withExtension: "html") else {
            setState(.error("User guide is missing from this build."))
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func exportSupportBundle() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.title = "Export DuckWhisperer Support Bundle"
        panel.nameFieldStringValue = SupportBundleExporter.suggestedFilename()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            NSApp.setActivationPolicy(.accessory)
            return
        }

        do {
            try SupportBundleExporter.export(
                to: url,
                selectedModel: selectedModel,
                inputLanguage: selectedInputLanguage,
                outputLanguage: selectedOutputLanguage,
                styleIntensity: selectedStyleIntensity,
                writingProfile: selectedWritingProfile
            )
            NSWorkspace.shared.activateFileViewerSelecting([url])
            AppLog.write("exported support bundle to \(url.path)")
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            AppLog.write("support bundle export failed: \(error.localizedDescription)")
        }
    }

    @objc private func checkForUpdates() {
        guard let url = URL(string: "https://github.com/byrondaniels/duckwhisperer/releases") else {
            return
        }
        NSWorkspace.shared.open(url)
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
            activeCommandName = nil
            activeInputLanguage = nil
            AppLog.write("recording cancelled with Escape")
            setState(.ready)
        case .transcribing:
            activeTranscriptionID = nil
            liveTranscriptionSession = nil
            pasteTarget = nil
            stopTranscriptionProgress()
            audioDucker.restore()
            activeCommandName = nil
            activeInputLanguage = nil
            AppLog.write("transcription cancelled with Escape")
            setState(.ready)
        case .ready, .error:
            break
        }
    }

    private func startRecording() {
        let inputLanguage = selectedInputLanguage
        guard let activeModelURL = ModelStore.installedURL(for: selectedModel, inputLanguage: inputLanguage) else {
            ensureSpeechModel(for: selectedModel, inputLanguage: inputLanguage) { [weak self] in
                self?.applyInputLanguage(inputLanguage)
            }
            NSSound.beep()
            return
        }

        let missingTranslationPacks = TranscriptionOutputPipeline
            .requiredTranslationPacks(inputLanguage: inputLanguage, outputLanguage: selectedOutputLanguage)
            .filter { !TranslationStore.isInstalled($0) }
        if !missingTranslationPacks.isEmpty {
            ensureTranslationPacks(inputLanguage: inputLanguage, outputLanguage: selectedOutputLanguage) {}
            NSSound.beep()
            return
        }

        logAccessibilityStateForRecording()

        do {
            activeCommandName = nil
            if tryItController.shouldReceiveTranscript {
                pasteTarget = nil
                activeAppName = "Try DuckWhisperer"
            } else {
                pasteTarget = PasteTargetDetector.captureFocusedEditableTarget()
                activeAppName = pasteTarget?.application?.localizedName
                applyAppDefaultsIfAvailable(for: pasteTarget?.application)
            }
            let postDefaultsMissingPacks = TranscriptionOutputPipeline
                .requiredTranslationPacks(inputLanguage: inputLanguage, outputLanguage: selectedOutputLanguage)
                .filter { !TranslationStore.isInstalled($0) }
            if !postDefaultsMissingPacks.isEmpty {
                ensureTranslationPacks(inputLanguage: inputLanguage, outputLanguage: selectedOutputLanguage) {}
                NSSound.beep()
                return
            }
            activeOutputLanguage = selectedOutputLanguage
            activeWritingProfile = selectedWritingProfile
            activeModelChoice = selectedModel
            activeInputLanguage = inputLanguage
            transcriber.setLanguageCode(inputLanguage.whisperCode)
            transcriber.setModelURL(activeModelURL)
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
        if let modelURL = ModelStore.installedURL(for: model, inputLanguage: selectedInputLanguage) {
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
        let audioDuration = Double(samples.count) / Double(WHISPER_SAMPLE_RATE)
        startTranscriptionProgress(audioDuration: audioDuration)
        let inputLanguage = activeInputLanguage ?? selectedInputLanguage
        let outputLanguage = activeOutputLanguage ?? selectedOutputLanguage
        let writingProfile = activeWritingProfile ?? selectedWritingProfile
        let styleIntensityPercent = selectedStyleIntensity.percent
        let modelChoice = activeModelChoice ?? selectedModel
        let appName = activeAppName
        let shouldPreserveCapitalization = preserveCapitalization
        let dictionaryEntries = personalDictionaryEntries
        let shouldTranslateAudioToEnglish = TranscriptionOutputPipeline.shouldUseWhisperEnglishTranslation(
            inputLanguage: inputLanguage,
            outputLanguage: outputLanguage
        )
        if shouldTranslateAudioToEnglish {
            liveSession?.stop()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let startedAt = Date()
                let transcript: String
                if shouldTranslateAudioToEnglish {
                    transcript = try self.transcriber.transcribe(samples: samples, translateToEnglish: true)
                } else {
                    transcript = try liveSession?.finish(with: samples)
                        ?? self.transcriber.transcribe(samples: samples)
                }
                let commandResult = CommandPhraseProcessor.process(
                    transcript,
                    outputLanguage: outputLanguage,
                    writingProfile: writingProfile
                )
                let dictionaryOutput = PersonalDictionary.apply(dictionaryEntries, to: commandResult.text)
                let willRunArgosTranslation = commandResult.outputLanguage.requiresTranslation
                    && !commandResult.outputLanguage.matchesInput(inputLanguage)
                if willRunArgosTranslation {
                    let targetLabel = commandResult.outputLanguage.title
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.isActiveTranscription(transcriptionID) else { return }
                        self.recordingOverlay.setDetails(
                            statusText: "Translating to \(targetLabel)",
                            contextText: self.overlayContextText(),
                            previewText: "Sending text through the local translator...",
                            hintText: "Esc cancels",
                            commandText: commandResult.commandName,
                            presenterMode: self.presenterModeEnabled
                        )
                    }
                }
                let translatedOutput: String
                do {
                    translatedOutput = try TranscriptionOutputPipeline.applyConfiguredOutputLanguage(
                        to: dictionaryOutput,
                        inputLanguage: inputLanguage,
                        outputLanguage: commandResult.outputLanguage
                    )
                } catch {
                    let fallbackDescription = shouldTranslateAudioToEnglish ? "English transcript" : "transcript"
                    AppLog.write("translation failed for \(commandResult.outputLanguage.title); falling back to \(fallbackDescription): \(error.localizedDescription)")
                    translatedOutput = dictionaryOutput
                }
                let languageOutput = self.applyLanguageOutput(
                    to: translatedOutput,
                    outputLanguage: commandResult.outputLanguage,
                    styleIntensityPercent: styleIntensityPercent
                )
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
                    self.activeCommandName = commandResult.commandName
                    self.completeTranscriptionProgress()
                    self.recordingOverlay.show(
                        progressPercent: 100,
                        statusText: "Pasting",
                        contextText: self.overlayContextText(),
                        previewText: output,
                        hintText: "Copied to clipboard",
                        commandText: commandResult.commandName,
                        presenterMode: self.presenterModeEnabled
                    )
                    AppLog.write(String(format: "transcribed %.2fs of audio in %.2fs", audioDuration, elapsed))
                    if let commandName = commandResult.commandName {
                        AppLog.write("command phrase applied: \(commandName)")
                    }
                    self.lastTranscript = output
                    self.copyToClipboard(output)
                    DictationStatsStore.record(text: output, spokenDuration: audioDuration)
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

    private func applyLanguageOutput(
        to text: String,
        outputLanguage: OutputLanguage,
        styleIntensityPercent: Int
    ) -> String {
        LanguageOutputRenderer.render(
            text,
            outputLanguage: outputLanguage,
            styleIntensityPercent: styleIntensityPercent
        )
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

        if tryItController.shouldReceiveTranscript {
            tryItController.insertTranscript(output)
            finishSuccessfulDelivery(output, transcriptionID: transcriptionID, undoTarget: nil, wasTryIt: true)
            return
        }

        let target = pasteTarget
        pasteTarget = nil

        guard AXIsProcessTrusted() else {
            AppLog.write("delivery fallback; Accessibility not trusted, transcript copied and transcript window shown")
            showPasteRecovery(
                output,
                reason: pasteRecoveryReason(
                    "Your text is safe and copied.",
                    target: target
                )
            )
            finishActiveTranscription(transcriptionID)
            setState(.ready)
            return
        }

        let finish: (_ allowFocusedCheckBypass: Bool, _ undoTarget: PasteTarget?) -> Void = { [weak self] allowFocusedCheckBypass, undoTarget in
            guard let self else { return }
            guard self.isActiveTranscription(transcriptionID) else {
                AppLog.write("delivery finish skipped after cancellation")
                return
            }
            if !self.pasteClipboardIntoFocusedTarget(allowWithoutFocusedCheck: allowFocusedCheckBypass) {
                self.showPasteRecovery(
                    output,
                    reason: self.pasteRecoveryReason(
                        "Your text is safe and copied. Click in the field you want, then choose Paste Again.",
                        target: target
                    )
                )
                self.finishActiveTranscription(transcriptionID)
                self.setState(.ready)
                return
            }
            self.finishSuccessfulDelivery(output, transcriptionID: transcriptionID, undoTarget: undoTarget)
        }

        guard let target
        else {
            AppLog.write("delivery target missing; attempting focused paste")
            finish(false, nil)
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
                    self.finishSuccessfulDelivery(output, transcriptionID: transcriptionID, undoTarget: target)
                    return
                }
                finish(true, target)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
        if let application = target.application, !application.isTerminated {
            application.activate(options: [])
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
                    self.finishSuccessfulDelivery(output, transcriptionID: transcriptionID, undoTarget: target)
                    return
                }
                finish(restoredFocus || target.application != nil, target)
            }
        }
    }

    private func showPasteRecovery(_ output: String, reason: String) {
        transcriptionResult.show(text: output, reason: reason)
    }

    private func pasteRecoveryReason(_ prefix: String, target: PasteTarget?) -> String {
        let readiness = PasteTargetDetector.readiness(for: target)
        return "\(prefix)\n\n\(readiness.title): \(readiness.detail)"
    }

    private func finishSuccessfulDelivery(
        _ output: String,
        transcriptionID: UUID?,
        undoTarget: PasteTarget?,
        wasTryIt: Bool = false
    ) {
        lastUndoTarget = undoTarget
        lastPasteWasTryIt = wasTryIt
        canUndoLastPaste = true
        undoLastPasteMenuItem.isEnabled = true
        finishActiveTranscription(transcriptionID)
        setState(.ready)
        showDeliverySuccessIfNeeded(output)
    }

    private func showDeliverySuccessIfNeeded(_ output: String) {
        guard presenterModeEnabled else {
            return
        }

        recordingOverlay.show(
            progressPercent: 100,
            statusText: "Pasted",
            contextText: "",
            previewText: output,
            hintText: "Ready for the next one",
            commandText: activeCommandName,
            presenterMode: true
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { [weak self] in
            guard let self, self.state == .ready else {
                return
            }
            self.recordingOverlay.hide()
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

        guard postCommandShortcut(keyCode: 9) else {
            AppLog.write("paste skipped; could not post paste shortcut")
            return false
        }
        AppLog.write("paste command posted")
        return true
    }

    private func postCommandShortcut(keyCode: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
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

    private func retryPaste(_ text: String) {
        copyToClipboard(text)

        guard AXIsProcessTrusted() else {
            showPasteRecovery(
                text,
                reason: pasteRecoveryReason(
                    "Paste-back still needs permission. Your text is copied, and the Fix Permission button will open the right setting.",
                    target: nil
                )
            )
            return
        }

        guard pasteClipboardIntoFocusedTarget() else {
            showPasteRecovery(
                text,
                reason: pasteRecoveryReason(
                    "Click in the field where you want this text, then choose Paste Again.",
                    target: nil
                )
            )
            return
        }

        transcriptionResult.close()
        lastUndoTarget = nil
        lastPasteWasTryIt = false
        canUndoLastPaste = true
        undoLastPasteMenuItem.isEnabled = true
        showDeliverySuccessIfNeeded(text)
    }

    @objc private func undoLastPaste() {
        guard canUndoLastPaste else {
            NSSound.beep()
            return
        }

        if lastPasteWasTryIt {
            if tryItController.undoLastInsertion() {
                clearUndoState()
            } else {
                NSSound.beep()
            }
            return
        }

        guard AXIsProcessTrusted() else {
            openAccessibilitySettings()
            return
        }

        if let lastUndoTarget {
            _ = PasteTargetDetector.focusCapturedTarget(lastUndoTarget)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            if self.postCommandShortcut(keyCode: 6) {
                AppLog.write("undo last paste command posted")
                self.clearUndoState()
            } else {
                NSSound.beep()
            }
        }
    }

    private func clearUndoState() {
        lastUndoTarget = nil
        lastPasteWasTryIt = false
        canUndoLastPaste = false
        undoLastPasteMenuItem.isEnabled = false
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
            self.modelExplorer.show(currentModel: self.selectedModel, inputLanguage: self.selectedInputLanguage)
        }
    }

    @objc private func openSetupDoctor() {
        showSetupDoctor()
    }

    private func showSetupDoctor() {
        setupDoctorController.show()
    }

    private func downloadDefaultModelForSetup() {
        ensureSpeechModel(
            for: ModelChoice.defaultChoice,
            inputLanguage: InputLanguageChoice.defaultChoice,
            onDownloadStateChange: { [weak self] downloading in
                self?.setupDoctorController.setModelDownloading(downloading)
            },
            completion: { [weak self] in
                self?.setupDoctorController.refreshChecks()
            }
        )
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
