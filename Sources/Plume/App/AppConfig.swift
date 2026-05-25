import Foundation

let hotKeySignature = fourCharCode("PLUM")
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
let appDisplayName = "Plume"
let supportDirectoryName = "Plume"
let legacySupportDirectoryName = "Local Whisperer"
let logFilename = "plume.log"
let buildMarker = "plume-2026-05-24-rebrand"
var debugPasteText: String?

func appSupportRootURL() -> URL {
    let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let currentURL = applicationSupportURL.appendingPathComponent(supportDirectoryName, isDirectory: true)
    let legacyURL = applicationSupportURL.appendingPathComponent(legacySupportDirectoryName, isDirectory: true)

    if !FileManager.default.fileExists(atPath: currentURL.path),
       FileManager.default.fileExists(atPath: legacyURL.path) {
        try? FileManager.default.copyItem(at: legacyURL, to: currentURL)
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
