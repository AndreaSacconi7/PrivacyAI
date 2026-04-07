import SwiftUI
import Foundation

@MainActor
class ChatStore: ObservableObject {
    @Published var savedChats: [ChatSession] = []
    
    // 1. Definiamo il percorso del file segreto sul disco dell'iPhone
    private let saveURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("privacy_ai_history.json")
    }()
    
    // 2. Quando l'app si avvia, carica automaticamente la cronologia
    init() {
        loadChatsFromDisk()
    }
    
    // Aggiungiamo "@discardableResult" per non avere avvisi se ignoriamo il risultato
    // e cambiamo il ritorno in "-> UUID?"
    @discardableResult
    func saveChat(messages: [Message], existingId: UUID?) -> UUID? {
        guard !messages.isEmpty else { return existingId }
        
        // 1. SE ESISTE GIA': Aggiorna e restituisce lo stesso ID
        if let id = existingId, let index = savedChats.firstIndex(where: { $0.id == id }) {
            savedChats[index].messages = messages
            savedChats[index].date = Date()
            
            let updatedSession = savedChats.remove(at: index)
            savedChats.insert(updatedSession, at: 0)
            
            saveChatsToDisk()
            
            return id // Restituisce l'ID esistente
        }
        
        // 2. SE È NUOVA (existingId è nil): Crea, salva e RESTITUISCE IL NUOVO ID
        let firstUserMessage = messages.first(where: { $0.role == .user })?.text ?? "Nuova Chat"
        let titleWords = firstUserMessage.split(separator: " ").prefix(3).joined(separator: " ")
        let title = titleWords.isEmpty ? "Chat Senza Titolo" : "\(titleWords)..."
        
        let newSession = ChatSession(title: title, date: Date(), messages: messages)
        savedChats.insert(newSession, at: 0)
        
        saveChatsToDisk() 
        return newSession.id // Restituisce il nuovo ID generato!
    }
    
    // --- FUNZIONI DI LETTURA E SCRITTURA ---
    
    private func saveChatsToDisk() {
        do {
            // Traduce l'array in dati JSON
            let data = try JSONEncoder().encode(savedChats)
            // Scrive i dati nel file (sovrascrivendo il vecchio)
            try data.write(to: saveURL)
            print("💾 Cronologia salvata su disco con successo!")
        } catch {
            print("❌ Errore nel salvataggio della cronologia: \(error.localizedDescription)")
        }
    }
    
    private func loadChatsFromDisk() {
        do {
            // Cerca il file sul disco
            let data = try Data(contentsOf: saveURL)
            // Traduce il JSON di nuovo in un array di ChatSession
            savedChats = try JSONDecoder().decode([ChatSession].self, from: data)
            print("📂 Cronologia caricata dal disco!")
        } catch {
            // Se fallisce (es. al primo avvio l'app non ha ancora il file), non fa niente
            print("Nessuna cronologia precedente trovata o errore: \(error.localizedDescription)")
        }
    }
}
