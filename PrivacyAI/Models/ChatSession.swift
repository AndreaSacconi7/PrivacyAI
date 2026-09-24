import Foundation

struct ChatSession: Identifiable, Codable {
    var id = UUID()
    var title: String
    var updatedAt: Date
    var messages: [Message]
    /// Alias mapping for this conversation. Persisted with the chat so that
    /// placeholders can still be restored after the app restarts.
    var pseudonymizer: Pseudonymizer

    init(messages: [Message] = []) {
        self.title = "New chat"
        self.updatedAt = Date()
        self.messages = messages
        self.pseudonymizer = Pseudonymizer()
    }

    /// Uses the first few words of the first user message as the title.
    mutating func refreshTitle() {
        guard let firstMessage = messages.first(where: { $0.role == .user && !$0.isError }) else { return }
        let words = firstMessage.text.split(whereSeparator: \.isWhitespace)
        title = words.prefix(5).joined(separator: " ") + (words.count > 5 ? "…" : "")
    }
}
