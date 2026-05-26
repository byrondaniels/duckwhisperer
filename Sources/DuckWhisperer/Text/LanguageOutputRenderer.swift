import Foundation

enum LanguageOutputRenderer {
    static func render(_ text: String, outputLanguage: OutputLanguage) -> String {
        guard text.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else {
            return text
        }

        switch outputLanguage.id {
        case "british":
            return StyledSpeech.british(text)
        case "genz":
            return StyledSpeech.genZ(text)
        case "alien":
            return StyledSpeech.alien(text)
        case "cowboy":
            return StyledSpeech.cowboy(text)
        case "pirate":
            return StyledSpeech.pirate(text)
        case "robot":
            return StyledSpeech.robot(text)
        case "shakespeare":
            return StyledSpeech.shakespeare(text)
        case "duck":
            return QuackSpeech.render(text)
        default:
            return text
        }
    }
}
