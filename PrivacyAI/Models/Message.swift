import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct Message: Identifiable, Equatable, Codable {
    var id = UUID()
    let role: MessageRole
    /// The text as the user sees it, with real names and places.
    let text: String
    /// The text as the LLM sees it, with placeholders. `nil` until the message is sent.
    var maskedText: String?
    var timestamp = Date()
    /// True while the message is on the review screen and its words can be tagged.
    var isReviewing = false
    /// App-generated notices (missing API key, network errors) that are shown
    /// in the chat but never sent to the LLM as conversation history.
    var isError = false
    var tokens: [WordToken]

    init(role: MessageRole, text: String, maskedText: String? = nil, isError: Bool = false) {
        self.role = role
        self.text = text
        self.maskedText = maskedText
        self.isError = isError
        self.tokens = WordToken.tokenize(text)
    }
}
