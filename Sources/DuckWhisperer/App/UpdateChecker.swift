import AppKit
import Foundation

struct AppUpdate {
    let tagName: String
    let releaseName: String
    let latestVersion: String
    let latestBuild: Int?
    let currentVersion: String
    let currentBuild: Int?
    let releaseURL: URL
    let downloadURL: URL?
    let assetName: String?

    var latestDisplayVersion: String {
        if let latestBuild {
            return "\(latestVersion) (\(latestBuild))"
        }
        return latestVersion
    }

    var currentDisplayVersion: String {
        if let currentBuild {
            return "\(currentVersion) (\(currentBuild))"
        }
        return currentVersion
    }
}

enum UpdateCheckOutcome {
    case updateAvailable(AppUpdate)
    case upToDate(latestVersion: String, latestBuild: Int?)
}

enum UpdateCheckerError: LocalizedError {
    case invalidResponse
    case releaseURLMissing

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub did not return a valid latest release response."
        case .releaseURLMissing:
            return "The latest release did not include a usable release URL."
        }
    }
}

enum UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/byrondaniels/duckwhisperer/releases/latest")!

    static func check(completion: @escaping (Result<UpdateCheckOutcome, Error>) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(appDisplayName)/\(currentVersion())", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                complete(.failure(error), completion: completion)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let data
            else {
                complete(.failure(UpdateCheckerError.invalidResponse), completion: completion)
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let outcome = try outcome(for: release)
                complete(.success(outcome), completion: completion)
            } catch {
                complete(.failure(error), completion: completion)
            }
        }.resume()
    }

    private static func complete(
        _ result: Result<UpdateCheckOutcome, Error>,
        completion: @escaping (Result<UpdateCheckOutcome, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private static func outcome(for release: GitHubRelease) throws -> UpdateCheckOutcome {
        guard let releaseURL = URL(string: release.htmlURL) else {
            throw UpdateCheckerError.releaseURLMissing
        }

        let latestVersion = normalizedVersion(release.tagName)
        let currentVersion = currentVersion()
        let dmgAsset = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        let latestBuild = dmgAsset.flatMap { buildNumber(from: $0.name, version: latestVersion) }
        let currentBuild = currentBuild()
        let versionComparison = compareVersions(latestVersion, currentVersion)
        let buildIsNewer = versionComparison == .orderedSame
            && latestBuild != nil
            && currentBuild != nil
            && latestBuild! > currentBuild!

        guard versionComparison == .orderedDescending || buildIsNewer else {
            return .upToDate(latestVersion: latestVersion, latestBuild: latestBuild)
        }

        return .updateAvailable(AppUpdate(
            tagName: release.tagName,
            releaseName: release.name ?? release.tagName,
            latestVersion: latestVersion,
            latestBuild: latestBuild,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            releaseURL: releaseURL,
            downloadURL: dmgAsset.flatMap { URL(string: $0.browserDownloadURL) },
            assetName: dmgAsset?.name
        ))
    }

    private static func currentVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func currentBuild() -> Int? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return nil
        }
        return Int(value)
    }

    private static func normalizedVersion(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        var left = numericVersionParts(lhs)
        var right = numericVersionParts(rhs)
        let count = max(left.count, right.count)
        while left.count < count { left.append(0) }
        while right.count < count { right.append(0) }

        for index in 0..<count {
            if left[index] > right[index] {
                return .orderedDescending
            }
            if left[index] < right[index] {
                return .orderedAscending
            }
        }
        return .orderedSame
    }

    private static func numericVersionParts(_ value: String) -> [Int] {
        let parts = value.split { !$0.isNumber }
            .compactMap { Int($0) }
        return parts.isEmpty ? [0] : parts
    }

    private static func buildNumber(from assetName: String, version: String) -> Int? {
        let escapedVersion = NSRegularExpression.escapedPattern(for: version)
        let pattern = #"^DuckWhisperer-\#(escapedVersion)-([0-9]+)\.dmg$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(assetName.startIndex..<assetName.endIndex, in: assetName)
        guard let match = regex.firstMatch(in: assetName, range: range),
              let buildRange = Range(match.range(at: 1), in: assetName)
        else {
            return nil
        }
        return Int(assetName[buildRange])
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
