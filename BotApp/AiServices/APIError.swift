import Foundation

// Definiamo i nostri errori personalizzati
enum APIError: Error, LocalizedError {
    case invalidKey(String)
    case badResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidKey(let message): return "⚠️ \(message)"
        case .badResponse: return "❌ Errore di connessione o formato API errato."
        case .networkError(let message): return "❌ Errore: \(message)"
        }
    }
}
