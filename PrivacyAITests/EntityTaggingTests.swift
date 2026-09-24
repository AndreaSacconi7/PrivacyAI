import Testing
@testable import PrivacyAI

struct EntityTaggingTests {
    @Test func tokenizeKeepsOriginalWhitespace() {
        let tokens = WordToken.tokenize("  Hello  there,\nworld ")
        #expect(tokens.map(\.text) == ["Hello", "there,", "world"])
        #expect(tokens.map(\.trailingWhitespace) == ["  ", "\n", " "])
        #expect(WordToken.tokenize("").isEmpty)
    }

    @Test func multiWordEntityTagsEveryWord() {
        let tokens = WordToken.tokenize("I met Mario Rossi, yesterday")
        let tagged = EntityRecognizer.tag(tokens, with: [RecognizedEntity(text: "mario rossi", category: .person)])

        #expect(tagged.map(\.category) == [nil, nil, .person, .person, nil])
    }

    @Test func matchingIgnoresCaseAndAccents() {
        // The uncased model returns lowercased, accent-stripped text.
        let tokens = WordToken.tokenize("José lives in Zürich")
        let tagged = EntityRecognizer.tag(tokens, with: [
            RecognizedEntity(text: "jose", category: .person),
            RecognizedEntity(text: "zurich", category: .location),
        ])

        #expect(tagged.map(\.category) == [.person, nil, nil, .location])
    }

    @Test func noEntitiesLeavesTokensUntouched() {
        let tokens = WordToken.tokenize("Nothing personal here")
        #expect(EntityRecognizer.tag(tokens, with: []) == tokens)
    }

    @Test(arguments: [
        ("sk-ant-api03-abc", LLMProvider.anthropic),
        ("sk-proj-abc", .openAI),
        ("gsk_abc", .groq),
        ("AIzaSyAbc", .gemini),
        ("  sk-ant-abc  ", .anthropic),
    ])
    func detectsProviderFromKey(key: String, provider: LLMProvider) {
        #expect(LLMProvider.detect(fromAPIKey: key) == provider)
    }

    @Test func unknownKeyFormatIsNotDetected() {
        #expect(LLMProvider.detect(fromAPIKey: "random-key") == nil)
        #expect(LLMProvider.detect(fromAPIKey: "") == nil)
    }

    @Test func consecutiveTurnsFromTheSameRoleAreMerged() {
        let merged = LLMClient.mergingConsecutiveRoles([
            LLMChatMessage(role: .user, content: "first"),
            LLMChatMessage(role: .user, content: "second"),
            LLMChatMessage(role: .assistant, content: "reply"),
        ])

        #expect(merged == [
            LLMChatMessage(role: .user, content: "first\n\nsecond"),
            LLMChatMessage(role: .assistant, content: "reply"),
        ])
    }

    @Test func markdownIsSplitIntoTextAndCode() {
        let segments = MarkdownSegment.parse("Try this:\n```swift\nprint(1)\n```\nDone.")
        #expect(segments == [.text("Try this:"), .code("print(1)"), .text("Done.")])
    }
}
