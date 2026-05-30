import Foundation

enum OfficeTranslationContext {
    static func normalizeEnglishSource(_ text: String) -> String {
        var output = text
        output = replace("\\bcurrent version is rough\\b", in: output, with: "current draft needs polishing")
        output = replace("\\bclean up the wording\\b", in: output, with: "polish the wording")
        output = replace("\\bwithout changing the numbers\\b", in: output, with: "without changing any numbers")
        output = replace("\\bpresentation deck\\b", in: output, with: "presentation")
        output = replace("\\bslide deck\\b", in: output, with: "presentation")
        output = replace("\\bdeck\\b", in: output, with: "presentation")
        output = replace("\\bvendor\\b", in: output, with: "supplier")
        output = replace("\\bcall ran long\\b", in: output, with: "meeting ran longer than expected")
        output = replace("\\bredlines\\b", in: output, with: "tracked edits")
        output = replace("\\blegal(?!\\s+team\\b)\\b", in: output, with: "the legal team")
        return output
    }

    static func cleanTranslatedOutput(_ text: String, targetCode: String) -> String {
        switch targetCode {
        case "nl":
            return cleanDutch(text)
        case "fr":
            return cleanFrench(text)
        default:
            return text
        }
    }

    private static func cleanDutch(_ text: String) -> String {
        var output = text
        output = replace("\\bVerzend\\s+(.+?)\\s+over\\s+aan\\b", in: output, with: "Verzend $1 naar")
        output = replace("\\bvóór lunch\\b", in: output, with: "vóór de lunch")
        output = replace("\\bpresentatiekaart\\b", in: output, with: "presentatie")
        output = replace("\\bverkoper\\b", in: output, with: "leverancier")
        output = replace("\\bde oproep\\b", in: output, with: "het gesprek")
        output = replace("\\brode lijnen\\b", in: output, with: "wijzigingen")
        output = replace("\\bworden gevolgd\\b", in: output, with: "bijgehouden")
        output = replace("\\bbijgewerkte versies\\b", in: output, with: "bijgehouden wijzigingen")
        output = replace("\\baangebrachte wijzigingen\\b", in: output, with: "bijgehouden wijzigingen")
        output = replace("\\bde\\s+lancingsplanning\\b", in: output, with: "het lanceringsplan")
        output = replace("\\bde\\s+lanceringsplanning\\b", in: output, with: "het lanceringsplan")
        output = replace("\\blancingsplanning\\b", in: output, with: "lanceringsplan")
        output = replace("\\blanceringsplanning\\b", in: output, with: "lanceringsplan")
        output = replace("\\blancering\\b", in: output, with: "lancering")
        return output
    }

    private static func cleanFrench(_ text: String) -> String {
        var output = text
        output = replace("\\bjeu de cartes\\b", in: output, with: "présentation")
        output = replace("\\blivret de présentation\\b", in: output, with: "présentation")
        output = replace("\\bvendeur\\b", in: output, with: "fournisseur")
        output = replace("\\blignes rouges\\b", in: output, with: "modifications suivies")
        output = replace("\\blangage\\b", in: output, with: "formulation")
        output = replace("\\bjeu de présentation\\b", in: output, with: "présentation")
        return output
    }

    private static func replace(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: [.regularExpression, .caseInsensitive]
        )
    }
}
