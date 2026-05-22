import AppKit
import Foundation

struct AppDefault: Codable {
    let appName: String
    let bundleIdentifier: String
    let modelID: String
    let outputLanguageID: String
    let writingProfileID: String
}

enum AppDefaultsStore {
    static func defaultForCurrentApp() -> AppDefault? {
        guard let application = PasteTargetDetector.currentExternalFrontmostApplication() else {
            return nil
        }
        return defaultFor(application)
    }

    static func defaultFor(_ application: NSRunningApplication?) -> AppDefault? {
        guard let key = key(for: application) else {
            return nil
        }
        return all()[key]
    }

    static func saveCurrentAppDefault(
        model: ModelChoice,
        outputLanguage: OutputLanguage,
        writingProfile: WritingProfile
    ) -> AppDefault? {
        guard let application = PasteTargetDetector.currentExternalFrontmostApplication(),
              let key = key(for: application)
        else {
            return nil
        }

        let appDefault = AppDefault(
            appName: application.localizedName ?? key,
            bundleIdentifier: key,
            modelID: model.id,
            outputLanguageID: outputLanguage.id,
            writingProfileID: writingProfile.id
        )
        var defaults = all()
        defaults[key] = appDefault
        save(defaults)
        return appDefault
    }

    static func clearCurrentAppDefault() -> AppDefault? {
        guard let application = PasteTargetDetector.currentExternalFrontmostApplication(),
              let key = key(for: application)
        else {
            return nil
        }
        var defaults = all()
        let removed = defaults.removeValue(forKey: key)
        save(defaults)
        return removed
    }

    static func all() -> [String: AppDefault] {
        guard let data = UserDefaults.standard.data(forKey: appDefaultsKey),
              let defaults = try? JSONDecoder().decode([String: AppDefault].self, from: data)
        else {
            return [:]
        }
        return defaults
    }

    private static func save(_ defaults: [String: AppDefault]) {
        if let data = try? JSONEncoder().encode(defaults) {
            UserDefaults.standard.set(data, forKey: appDefaultsKey)
        }
    }

    private static func key(for application: NSRunningApplication?) -> String? {
        guard let application else {
            return nil
        }
        if let bundleIdentifier = application.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        return application.localizedName
    }
}
