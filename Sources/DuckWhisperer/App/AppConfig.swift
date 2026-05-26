import Foundation

let hotKeySignature = fourCharCode("DUCK")
let recordHotKeyIdentifier: UInt32 = 1
let cancelHotKeyIdentifier: UInt32 = 3
let selectedModelIDKey = "SelectedModelID"
let selectedInputLanguageIDKey = "SelectedInputLanguageID"
let selectedOutputLanguageIDKey = "SelectedOutputLanguageID"
let selectedWritingProfileIDKey = "SelectedWritingProfileID"
let preserveCapitalizationKey = "PreserveCapitalization"
let audioDuckingEnabledKey = "AudioDuckingEnabled"
let presenterModeEnabledKey = "PresenterModeEnabled"
let appDefaultsKey = "AppDefaults"
let personalDictionaryTextKey = "PersonalDictionaryText"
let transcriptHistoryKey = "TranscriptHistory"
let dictationStatsKey = "DictationStats"
let hasSeenOnboardingKey = "HasSeenOnboarding"
let recordShortcutPresetIDKey = "RecordShortcutPresetID"
let appDisplayName = "DuckWhisperer"
let supportDirectoryName = "DuckWhisperer"
let legacySupportDirectoryNames = ["Plume", "Local Whisperer"]
let logFilename = "duckwhisperer.log"
var debugPasteText: String?

func appSupportRootURL() -> URL {
    let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let currentURL = applicationSupportURL.appendingPathComponent(supportDirectoryName, isDirectory: true)

    if !FileManager.default.fileExists(atPath: currentURL.path) {
        for legacyName in legacySupportDirectoryNames {
            let legacyURL = applicationSupportURL.appendingPathComponent(legacyName, isDirectory: true)
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try? FileManager.default.copyItem(at: legacyURL, to: currentURL)
                break
            }
        }
    }

    return currentURL
}

private func fourCharCode(_ value: String) -> OSType {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + scalar.value
    }
    return result
}
