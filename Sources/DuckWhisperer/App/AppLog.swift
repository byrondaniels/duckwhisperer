import Foundation

enum AppLog {
    static var url: URL {
        appSupportRootURL().appendingPathComponent(logFilename)
    }

    static func write(_ message: String) {
        let supportURL = appSupportRootURL()
        let logURL = url
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"

        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logURL.path) {
                try Data().write(to: logURL)
            }
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            fputs("\(appDisplayName) log failed: \(error.localizedDescription)\n", stderr)
        }
    }
}
