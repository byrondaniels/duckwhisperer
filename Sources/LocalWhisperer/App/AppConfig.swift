import Foundation

let hotKeySignature = fourCharCode("LWSP")
let recordHotKeyIdentifier: UInt32 = 1
let translateSelectionHotKeyIdentifier: UInt32 = 2
let selectedModelIDKey = "SelectedModelID"
let selectedOutputLanguageIDKey = "SelectedOutputLanguageID"
let preserveCapitalizationKey = "PreserveCapitalization"
let appDisplayName = "DuckWhisperer"
let supportDirectoryName = "Local Whisperer"
let logFilename = "duckwhisperer.log"
let buildMarker = "duckwhisperer-2026-05-21-selection-translate"
var debugPasteText: String?

private func fourCharCode(_ value: String) -> OSType {
    var result: UInt32 = 0
    for scalar in value.unicodeScalars.prefix(4) {
        result = (result << 8) + scalar.value
    }
    return result
}
