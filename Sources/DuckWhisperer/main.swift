import AppKit

runSmokeTranscriptionIfRequested()
captureDebugPasteTextIfRequested()

private let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()
