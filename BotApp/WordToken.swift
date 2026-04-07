import Foundation

// Questa struct rappresenta una singola parola e il suo stato attuale
struct WordToken: Identifiable, Equatable, Codable {
    let id = UUID()
    let text: String
    var category: String? = nil
    var censoredText: String? = nil
}
