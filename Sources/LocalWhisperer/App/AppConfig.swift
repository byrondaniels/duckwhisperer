import Foundation

let hotKeySignature = fourCharCode("LWSP")
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
let hasSeenOnboardingKey = "HasSeenOnboarding"
let appDisplayName = "DuckWhisperer"
let supportDirectoryName = "Local Whisperer"
let logFilename = "duckwhisperer.log"
let buildMarker = "duckwhisperer-2026-05-22-tiktok-polish"
var debugPasteText: String?

private func fourCharCode(_ value: String) -> OSType {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + scalar.value
    }
    return result
}
