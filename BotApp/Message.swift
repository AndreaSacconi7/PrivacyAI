import Foundation

// Definiamo chi ha inviato il messaggio
enum MessageRole: Codable {
    case user
    case assistant
}

// La struttura del messaggio
struct Message: Identifiable, Equatable, Codable {
    let id: UUID
    let text: String
    let role: MessageRole
    let timestamp: Date
    var isReviewing: Bool
    var censoredText: String? = nil
    
    // ECCO LA NOVITÀ: L'array di parole interattive
    var tokens: [WordToken]
    
    // Creiamo un costruttore personalizzato (init)
    // Così quando crei un messaggio, passi solo il testo e lui fa il lavoro sporco!
    init(text: String, role: MessageRole) {
        self.text = text
        self.role = role
        self.isReviewing = false
        self.id = UUID()
        self.timestamp = Date()
        // Dividiamo la frase in parole e creiamo i WordToken automaticamente
        self.tokens = text.split(separator: " ").map {
            WordToken(text: String($0))
        }
    }
    
    init(text: String, role: MessageRole, censoredText: String) {
        self.text = text
        self.role = role
        self.isReviewing = false
        self.id = UUID()
        self.timestamp = Date()
        self.censoredText = censoredText
        // Dividiamo la frase in parole e creiamo i WordToken automaticamente
        self.tokens = text.split(separator: " ").map {
            WordToken(text: String($0))
        }
    }
}
