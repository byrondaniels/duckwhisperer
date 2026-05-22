import Foundation

struct OutputLanguage: Equatable {
    let id: String
    let title: String
    let translationTargetCode: String?

    var requiresTranslation: Bool {
        translationTargetCode != nil
    }

    static let all: [OutputLanguage] = [
        OutputLanguage(id: "en", title: "English", translationTargetCode: nil),
        OutputLanguage(id: "fr", title: "French", translationTargetCode: "fr"),
        OutputLanguage(id: "nl", title: "Dutch", translationTargetCode: "nl"),
        OutputLanguage(id: "duck", title: "Duck", translationTargetCode: nil)
    ]

    static var defaultChoice: OutputLanguage {
        all[0]
    }

    static func choice(for id: String?) -> OutputLanguage {
        all.first { $0.id == id } ?? defaultChoice
    }
}
