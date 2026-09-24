import Foundation
import Testing
@testable import PrivacyAI

struct PseudonymizerTests {
    /// Builds tokens from `text` and tags the words listed in `tags`.
    private func tokens(_ text: String, tags: [String: EntityCategory]) -> [WordToken] {
        WordToken.tokenize(text).map { token in
            var token = token
            token.category = tags[token.text]
            return token
        }
    }

    @Test func masksTaggedWordsAndKeepsTheRest() {
        var pseudonymizer = Pseudonymizer()
        let result = pseudonymizer.mask(tokens("Mario lives in Milan", tags: ["Mario": .person, "Milan": .location]))

        #expect(result.maskedText == "[PERSON_1] lives in [LOCATION_1]")
        #expect(result.tokens.map(\.maskedText) == ["[PERSON_1]", nil, nil, "[LOCATION_1]"])
    }

    @Test func sameEntityKeepsItsAliasAcrossMessagesAndCasing() {
        var pseudonymizer = Pseudonymizer()
        _ = pseudonymizer.mask(tokens("Mario called", tags: ["Mario": .person]))
        let second = pseudonymizer.mask(tokens("MARIO and Luigi", tags: ["MARIO": .person, "Luigi": .person]))

        #expect(second.maskedText == "[PERSON_1] and [PERSON_2]")
    }

    @Test func countersArePerCategory() {
        var pseudonymizer = Pseudonymizer()
        let result = pseudonymizer.mask(tokens(
            "Anna Rome Acme Bob",
            tags: ["Anna": .person, "Rome": .location, "Acme": .organization, "Bob": .person]
        ))

        #expect(result.maskedText == "[PERSON_1] [LOCATION_1] [ORG_1] [PERSON_2]")
    }

    @Test func keepsPunctuationPossessivesAndWhitespace() {
        var pseudonymizer = Pseudonymizer()
        let result = pseudonymizer.mask(tokens(
            "(Mario's) friend,\nfrom Milan.",
            tags: ["(Mario's)": .person, "Milan.": .location]
        ))

        #expect(result.maskedText == "([PERSON_1]'s) friend,\nfrom [LOCATION_1].")
    }

    @Test func untaggedMessageIsSentUnchanged() {
        var pseudonymizer = Pseudonymizer()
        let text = "How do I  bake\nbread?"
        #expect(pseudonymizer.mask(WordToken.tokenize(text)).maskedText == text)
    }

    @Test func restoreRoundTrip() {
        var pseudonymizer = Pseudonymizer()
        _ = pseudonymizer.mask(tokens("Mario lives in Milan", tags: ["Mario": .person, "Milan": .location]))

        let reply = "[PERSON_1] should visit the Duomo in [LOCATION_1]."
        #expect(pseudonymizer.restore(reply) == "Mario should visit the Duomo in Milan.")
    }

    @Test func restoreDoesNotConfuseSimilarAliases() {
        var pseudonymizer = Pseudonymizer()
        for index in 1...10 {
            _ = pseudonymizer.alias(for: "Name\(index)", category: .person)
        }

        #expect(pseudonymizer.restore("[PERSON_10] and [PERSON_1]") == "Name10 and Name1")
    }

    @Test func consecutiveWordsWithTheSameTagBecomeOneEntity() {
        var pseudonymizer = Pseudonymizer()
        let result = pseudonymizer.mask(tokens(
            "Mario Rossi moved to New York's center",
            tags: ["Mario": .person, "Rossi": .person, "New": .location, "York's": .location]
        ))

        #expect(result.maskedText == "[PERSON_1] moved to [LOCATION_1]'s center")
        #expect(result.tokens.map(\.maskedText) == ["[PERSON_1]", "", nil, nil, "[LOCATION_1]'s", "", nil])
        #expect(pseudonymizer.restore("Say hi to [PERSON_1]") == "Say hi to Mario Rossi")
    }

    @Test func punctuationOrLineBreakSeparatesEntities() {
        var pseudonymizer = Pseudonymizer()
        let result = pseudonymizer.mask(tokens(
            "Milan, Rome\nParis",
            tags: ["Milan,": .location, "Rome": .location, "Paris": .location]
        ))

        #expect(result.maskedText == "[LOCATION_1], [LOCATION_2]\n[LOCATION_3]")
    }

    @Test func remembersCategoriesOfMaskedWords() {
        var pseudonymizer = Pseudonymizer()
        _ = pseudonymizer.mask(tokens("Mario Rossi", tags: ["Mario": .person, "Rossi": .person]))

        #expect(pseudonymizer.knownCategory(for: "rossi,") == .person)
        #expect(pseudonymizer.knownCategory(for: "Rome") == nil)
    }

    @Test func survivesEncodingRoundTrip() throws {
        var pseudonymizer = Pseudonymizer()
        _ = pseudonymizer.mask(tokens("Mario", tags: ["Mario": .person]))

        var decoded = try JSONDecoder().decode(Pseudonymizer.self, from: JSONEncoder().encode(pseudonymizer))
        #expect(decoded == pseudonymizer)
        // The counter survives too, so the next person gets a new alias.
        #expect(decoded.alias(for: "Luigi", category: .person) == "[PERSON_2]")
    }

    @Test(arguments: [
        ("Mario", "", "Mario", ""),
        ("(Mario),", "(", "Mario", "),"),
        ("Mario's", "", "Mario", "'s"),
        ("O'Neil", "", "O'Neil", ""),
        ("...", "...", "", ""),
    ])
    func splitsWordFromPunctuation(word: String, leading: String, core: String, trailing: String) {
        let parts = Pseudonymizer.split(word)
        #expect(parts.leading == leading)
        #expect(parts.core == core)
        #expect(parts.trailing == trailing)
    }
}
