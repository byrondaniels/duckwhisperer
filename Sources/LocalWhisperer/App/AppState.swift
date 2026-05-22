import Foundation

enum AppState: Equatable {
    case ready
    case recording
    case transcribing
    case error(String)

    var statusText: String {
        switch self {
        case .ready:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

}
