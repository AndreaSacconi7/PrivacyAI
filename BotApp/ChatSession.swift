import Foundation

struct ChatSession: Identifiable, Codable {
    let id = UUID()
    var title: String
    var date: Date
    var messages: [Message] // L'elenco dei messaggi di quella specifica chat
}
