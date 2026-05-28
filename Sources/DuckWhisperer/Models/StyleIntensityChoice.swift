import Foundation

struct StyleIntensityChoice: Equatable {
    let percent: Int
    let title: String
    let detail: String

    static let all: [StyleIntensityChoice] = [
        StyleIntensityChoice(percent: 0, title: "Off - 0%", detail: "Keep the transcript unchanged."),
        StyleIntensityChoice(percent: 25, title: "Light - 25%", detail: "Mostly phrase rewrites with a few signature words."),
        StyleIntensityChoice(percent: 50, title: "Balanced - 50%", detail: "Phrase rewrites plus common style vocabulary."),
        StyleIntensityChoice(percent: 75, title: "Strong - 75%", detail: "More aggressive word and phrase rewrites."),
        StyleIntensityChoice(percent: 100, title: "Maximum - 100%", detail: "Apply every matching style rewrite.")
    ]

    static var defaultChoice: StyleIntensityChoice {
        choice(for: 100)
    }

    static func choice(for percent: Int?) -> StyleIntensityChoice {
        guard let percent else {
            return defaultChoice
        }
        if let exact = all.first(where: { $0.percent == percent }) {
            return exact
        }
        return all.min(by: { abs($0.percent - percent) < abs($1.percent - percent) }) ?? defaultChoice
    }
}
