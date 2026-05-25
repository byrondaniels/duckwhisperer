import Foundation

enum PlumeError: LocalizedError {
    case audioReadFailed(String)
    case hotKeyFailed(OSStatus)
    case modelDownloadFailed(String)
    case modelLoadFailed(String)
    case modelMissing(String)
    case noRecording
    case recordingFailed
    case styleRewriteFailed(String)
    case styleRewriteInstallFailed(String)
    case styleRewriteRuntimeMissing(String)
    case supportBundleFailed(String)
    case translationFailed(String)
    case translationInstallFailed(String)
    case translationModelMissing(String)
    case translationRuntimeMissing(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioReadFailed(let message):
            return message
        case .hotKeyFailed(let status):
            return "Could not register Option+Space. Another app may already own that shortcut. OSStatus \(status)."
        case .modelDownloadFailed(let message):
            return "Model download failed: \(message)"
        case .modelLoadFailed(let path):
            return "Could not load the Whisper model at \(path)."
        case .modelMissing(let path):
            return "Missing Whisper model at \(path)."
        case .noRecording:
            return "No active recording."
        case .recordingFailed:
            return "The microphone did not start recording."
        case .styleRewriteFailed(let message):
            return "Style rewrite failed: \(message)"
        case .styleRewriteInstallFailed(let message):
            return "Style rewrite install failed: \(message)"
        case .styleRewriteRuntimeMissing(let message):
            return "Missing local style runner: \(message)"
        case .supportBundleFailed(let message):
            return "Support bundle failed: \(message)"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .translationInstallFailed(let message):
            return "Translation install failed: \(message)"
        case .translationModelMissing(let path):
            return "Missing local translation data at \(path). Install the matching translator from Speed & Accuracy."
        case .translationRuntimeMissing(let path):
            return "Missing local translation runtime at \(path). Install a translator from Speed & Accuracy."
        case .transcriptionFailed(let message):
            return message
        }
    }
}
