import Foundation

struct InputLanguageChoice: Equatable {
    let id: String
    let title: String
    let whisperCode: String

    var isEnglish: Bool {
        whisperCode == "en"
    }

    static let all: [InputLanguageChoice] = [
        InputLanguageChoice(id: "en", title: "English", whisperCode: "en"),
        InputLanguageChoice(id: "es", title: "Spanish", whisperCode: "es"),
        InputLanguageChoice(id: "fr", title: "French", whisperCode: "fr"),
        InputLanguageChoice(id: "tl", title: "Tagalog", whisperCode: "tl"),
        InputLanguageChoice(id: "zh", title: "Chinese (Mandarin)", whisperCode: "zh"),
        InputLanguageChoice(id: "hi", title: "Hindi", whisperCode: "hi"),
        InputLanguageChoice(id: "ar", title: "Arabic", whisperCode: "ar"),
        InputLanguageChoice(id: "bn", title: "Bengali", whisperCode: "bn"),
        InputLanguageChoice(id: "pt", title: "Portuguese", whisperCode: "pt"),
        InputLanguageChoice(id: "ru", title: "Russian", whisperCode: "ru"),
        InputLanguageChoice(id: "ur", title: "Urdu", whisperCode: "ur"),
        InputLanguageChoice(id: "id", title: "Indonesian", whisperCode: "id"),
        InputLanguageChoice(id: "de", title: "German", whisperCode: "de"),
        InputLanguageChoice(id: "ja", title: "Japanese", whisperCode: "ja"),
        InputLanguageChoice(id: "ko", title: "Korean", whisperCode: "ko"),
        InputLanguageChoice(id: "tr", title: "Turkish", whisperCode: "tr"),
        InputLanguageChoice(id: "vi", title: "Vietnamese", whisperCode: "vi"),
        InputLanguageChoice(id: "it", title: "Italian", whisperCode: "it"),
        InputLanguageChoice(id: "pl", title: "Polish", whisperCode: "pl"),
        InputLanguageChoice(id: "nl", title: "Dutch", whisperCode: "nl")
    ]

    static var defaultChoice: InputLanguageChoice {
        all[0]
    }

    static func choice(for id: String?) -> InputLanguageChoice {
        all.first { $0.id == id } ?? defaultChoice
    }
}
