import Foundation

struct OutputLanguage: Equatable {
    let id: String
    let title: String
    let languageCode: String?
    let translationTargetCode: String?

    init(id: String, title: String, languageCode: String? = nil, translationTargetCode: String? = nil) {
        self.id = id
        self.title = title
        self.languageCode = languageCode
        self.translationTargetCode = translationTargetCode
    }

    var isSameAsInput: Bool {
        id == "same-input"
    }

    var isEnglishLanguage: Bool {
        languageCode == "en"
    }

    var requiresTranslation: Bool {
        translationTargetCode != nil
    }

    func matchesInput(_ inputLanguage: InputLanguageChoice) -> Bool {
        isSameAsInput || languageCode == inputLanguage.whisperCode
    }

    func effectiveTitle(for inputLanguage: InputLanguageChoice) -> String {
        isSameAsInput ? inputLanguage.title : title
    }

    static let all: [OutputLanguage] = [
        OutputLanguage(id: "same-input", title: "Same as Input"),
        OutputLanguage(id: "en", title: "English", languageCode: "en"),
        OutputLanguage(id: "fr", title: "French", languageCode: "fr", translationTargetCode: "fr"),
        OutputLanguage(id: "nl", title: "Dutch", languageCode: "nl", translationTargetCode: "nl"),
        OutputLanguage(id: "british", title: "British", translationTargetCode: nil),
        OutputLanguage(id: "genz", title: "Gen Z", translationTargetCode: nil),
        OutputLanguage(id: "genalpha", title: "Gen Alpha", translationTargetCode: nil),
        OutputLanguage(id: "boomer", title: "Boomer", translationTargetCode: nil),
        OutputLanguage(id: "alien", title: "Alien", translationTargetCode: nil),
        OutputLanguage(id: "cowboy", title: "Cowboy", translationTargetCode: nil),
        OutputLanguage(id: "pirate", title: "Pirate", translationTargetCode: nil),
        OutputLanguage(id: "robot", title: "Robot", translationTargetCode: nil),
        OutputLanguage(id: "shakespeare", title: "Shakespeare", translationTargetCode: nil),
        OutputLanguage(id: "duck", title: "Quack", translationTargetCode: nil)
    ]

    static var defaultChoice: OutputLanguage {
        all[0]
    }

    static func choice(for id: String?) -> OutputLanguage {
        all.first { $0.id == id } ?? defaultChoice
    }
}
