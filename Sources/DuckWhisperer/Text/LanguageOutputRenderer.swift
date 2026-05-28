import Foundation

enum LanguageOutputRenderer {
    static func render(
        _ text: String,
        outputLanguage: OutputLanguage,
        styleIntensityPercent: Int = StyleIntensityChoice.defaultChoice.percent
    ) -> String {
        guard text.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else {
            return text
        }

        switch outputLanguage.id {
        case "british":
            return StyledSpeech.british(text, intensityPercent: styleIntensityPercent)
        case "genz":
            return StyledSpeech.genZ(text, intensityPercent: styleIntensityPercent)
        case "genalpha":
            return StyledSpeech.genAlpha(text, intensityPercent: styleIntensityPercent)
        case "millennial":
            return StyledSpeech.millennial(text, intensityPercent: styleIntensityPercent)
        case "boomer":
            return StyledSpeech.boomer(text, intensityPercent: styleIntensityPercent)
        case "alien":
            return StyledSpeech.alien(text)
        case "cowboy":
            return StyledSpeech.cowboy(text, intensityPercent: styleIntensityPercent)
        case "pirate":
            return StyledSpeech.pirate(text, intensityPercent: styleIntensityPercent)
        case "robot":
            return StyledSpeech.robot(text)
        case "shakespeare":
            return StyledSpeech.shakespeare(text, intensityPercent: styleIntensityPercent)
        case "duck":
            return QuackSpeech.render(text)
        default:
            return text
        }
    }
}
