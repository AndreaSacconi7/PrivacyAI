import Foundation

/// A single whitespace-delimited word of a message, plus its privacy state.
struct WordToken: Identifiable, Equatable, Codable {
    var id = UUID()
    let text: String
    /// The whitespace that followed the word in the original text, so the
    /// message can be rebuilt exactly (newlines included).
    var trailingWhitespace: String = " "
    /// Set when the word was tagged as personal information.
    var category: EntityCategory?
    /// What replaced the word in the prompt sent to the LLM, e.g. `[PERSON_1],`.
    var maskedText: String?

    func displayText(masked: Bool) -> String {
        masked ? (maskedText ?? text) : text
    }

    /// Splits `text` into word tokens, keeping the whitespace between them.
    static func tokenize(_ text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let wordEnd = text[index...].firstIndex(where: \.isWhitespace) ?? text.endIndex
            let spaceEnd = text[wordEnd...].firstIndex(where: { !$0.isWhitespace }) ?? text.endIndex
            if wordEnd > index {
                tokens.append(WordToken(
                    text: String(text[index..<wordEnd]),
                    trailingWhitespace: String(text[wordEnd..<spaceEnd])
                ))
            }
            index = spaceEnd
        }
        return tokens
    }
}
