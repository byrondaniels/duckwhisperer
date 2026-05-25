import Foundation

final class AudioDucker {
    private var previousVolume: Int?

    func duckIfNeeded(enabled: Bool) {
        guard enabled, previousVolume == nil else {
            return
        }

        guard let currentVolume = Self.currentOutputVolume() else {
            AppLog.write("audio ducking skipped; could not read output volume")
            return
        }

        previousVolume = currentVolume
        let duckedVolume = min(currentVolume, 35)
        guard duckedVolume < currentVolume else {
            return
        }

        Self.setOutputVolume(duckedVolume)
        AppLog.write("audio ducking set output volume \(currentVolume) -> \(duckedVolume)")
    }

    func restore() {
        guard let previousVolume else {
            return
        }
        Self.setOutputVolume(previousVolume)
        AppLog.write("audio ducking restored output volume to \(previousVolume)")
        self.previousVolume = nil
    }

    private static func currentOutputVolume() -> Int? {
        let script = "output volume of (get volume settings)"
        let output = runAppleScript(script)
        return output.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func setOutputVolume(_ volume: Int) {
        _ = runAppleScript("set volume output volume \(max(0, min(100, volume)))")
    }

    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
