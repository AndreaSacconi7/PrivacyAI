// ChatViewModel.swift
import SwiftUI

import SwiftUI
import CoreML
import NaturalLanguage
import Hub
import Tokenizers

@MainActor
class ChatViewModel: ObservableObject {
    
    // MARK: - Proprietà UI (Chat Base)
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var showReviewScreen: Bool = false
    @Published var pendingMessage: Message = Message(text: "", role: .user)
    @Published var currentSessionId: UUID? = nil
    
    // MARK: - Proprietà AI & Privacy
    @Published var isAIReady: Bool = false
    private var customDistilBERTModel: DistilBERT_NER_Multilingua?
    private var tokenizer: Tokenizer? // Assicurati di avere la classe Tokenizer nel progetto
    
    // Il "Caveau" dei Dati Sensibili
    private var originalToAlias: [String: String] = [:]
    private var aliasToOriginal: [String: String] = [:]
    private var counters: [String: Int] = ["NOME": 1, "LUOGO": 1, "ORG": 1, "GENERIC": 1]
    
    private let idToLabel: [Int: String] = [
        0: "O", 1: "B-PER", 2: "I-PER", 3: "B-ORG", 4: "I-ORG", 5: "B-LOC", 6: "I-LOC", 7: "B-MISC", 8: "I-MISC"
    ]
    
    //Privacy overlay
    @Published var isPrivacyOverlayOpened: Bool = false
    @Published var privacyMessageToShow: Message = Message(text: "", role: .user)
    
    init() {
        // Avvia il caricamento del modello AI appena si apre l'app
        Task { await setupAI() }
    }
    
    func loadChat(session: ChatSession) {
        self.messages = session.messages
        self.currentSessionId = session.id // Ora si ricorda l'ID!
        self.inputText = ""
    }
    
    // Resetta tutto per una nuova chat
    func startNewChat() {
        self.messages.removeAll()
        self.currentSessionId = nil // Resetta l'ID
        self.inputText = ""
    }
    
    // MARK: - 1. Setup dell'AI (Identico al tuo)
    func setupAI() async {
        guard !isAIReady else { return }
        do {
            let model = try await Task.detached(priority: .userInitiated) {
                try DistilBERT_NER_Multilingua(configuration: MLModelConfiguration())
            }.value
            
            self.customDistilBERTModel = model
            // self.tokenizer = try await AutoTokenizer.from(pretrained: "distilbert-base-multilingual-cased") // Scommenta se hai il tokenizer pronto
            
            self.isAIReady = true
            print("✅ Intelligenza Artificiale Pronta!")
        } catch {
            print("❌ Errore caricamento AI: \(error)")
        }
    }
    
    // MARK: - 2. Preparazione per la Review (Auto-Tagging)
    func prepareForReview() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 1. Creiamo il messaggio "vuoto" (i token sono tutti senza categoria all'inizio)
        var newPendingMessage = Message(text: text, role: .user)
        
        newPendingMessage.isReviewing = true
        
        // 2. Lanciamo l'analisi AI (BERT + NLTagger)
        // Questa funzione (che abbiamo visto nei passaggi precedenti)
        // restituisce un dizionario [Parola : Categoria]
        let aiResults = await runAllAIModels(on: text)
        
        print("founded categories")
        // 3. Mappiamo i risultati dell'AI sui nostri token
        for i in 0..<newPendingMessage.tokens.count {
            let word = newPendingMessage.tokens[i].text
            
            // Puliamo la parola da punteggiatura per il confronto (es: "Roma," -> "Roma")
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        
            if let categoryFoundByAI = aiResults[cleanWord] {
                // Se l'AI ha trovato una corrispondenza, assegniamo la categoria al token
                print(categoryFoundByAI)
                newPendingMessage.tokens[i].category = categoryFoundByAI
            }
        }
        
        // 4. Aggiorniamo la UI
        self.pendingMessage = newPendingMessage
        //self.lastTextMessage = text
        self.showReviewScreen = true
    }
    
    // MARK: - 3. Invio Definitivo (Censura basata sui Token)
    func confirmAndSendMessage(reviewedMessage: Message) {
        // Salviamo il messaggio in chiaro nella UI (così l'utente vede cosa ha scritto)
        
        // 1. Costruiamo la frase censurata partendo dai token che l'utente ha confermato/modificato
        var censoredSentence = ""
        
        var finalMessage = reviewedMessage
        
        for i in 0..<finalMessage.tokens.count {
                if let category = finalMessage.tokens[i].category {
                    // Genera l'alias (es. [PERSON_1])
                    let alias = getOrCreateAlias(for: finalMessage.tokens[i].text, category: category)
                    
                    // 👇 INSERIAMO IL TESTO CENSURATO NEL TOKEN
                    finalMessage.tokens[i].censoredText = alias
                    
                    censoredSentence += alias + " "
                } else {
                    censoredSentence += finalMessage.tokens[i].text + " "
                }
            }
        
        let finalCensoredString = censoredSentence.trimmingCharacters(in: .whitespaces)
        print("🔒 Testo inviato all'API: \(finalCensoredString)")
        
        finalMessage.isReviewing = false
//        finalMessage.censoredText = finalCensoredString
        
        self.messages.append(finalMessage)
        self.inputText = ""
        
        // 2. Inviamo la stringa censurata all'API
        fetchAssistantResponse(censoredPrompt: finalCensoredString)
    }
    
    func fetchAssistantResponse(censoredPrompt: String) {
        let savedApiKey = UserDefaults.standard.string(forKey: "user_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let savedProviderString = UserDefaults.standard.string(forKey: "selected_provider") ?? AIProvider.auto.rawValue
        let savedProvider = AIProvider(rawValue: savedProviderString) ?? .auto
        
        guard !savedApiKey.isEmpty else {
            self.messages.append(Message(text: "⚠️ Inserisci una API Key nelle impostazioni per continuare.", role: .assistant))
            return
        }
        
        self.isTyping = true
        
        Task {
            do {
                // 1. Dichiariamo una variabile vuota che conterrà la risposta
                let rawAIAnswer: String
                
                // 2. Chiamiamo il nostro nuovo Servizio Esterno a seconda del provider
                switch savedProvider {
                case .openai:
                    rawAIAnswer = try await AIApiService.shared.fetchOpenAIFormat(
                        prompt: censoredPrompt, apiKey: savedApiKey,
                        endpoint: "https://api.openai.com/v1/chat/completions",
                        model: "gpt-4o"
                    )
                case .anthropic:
                    rawAIAnswer = try await AIApiService.shared.fetchAnthropic(prompt: censoredPrompt, apiKey: savedApiKey)
                case .gemini:
                    rawAIAnswer = try await AIApiService.shared.fetchGemini(prompt: censoredPrompt, apiKey: savedApiKey)
                case .groq:
                    // Fallback su Groq
                    rawAIAnswer = try await AIApiService.shared.fetchOpenAIFormat(
                        prompt: censoredPrompt, apiKey: savedApiKey,
                        endpoint: "https://api.groq.com/openai/v1/chat/completions",
                        model: "llama-3.1-8b-instant"
                    )
                case .auto:
                    // Se siamo qui, il rilevamento automatico ha fallito
                    // e l'utente non ha scelto un provider manualmente.
                    await MainActor.run {
                        self.messages.append(Message(
                            text: "⚠️ API Key Provider non riconosciuto. Per favore, seleziona manualmente il provider corretto (OpenAI, Claude, Gemini ecc...) nelle impostazioni.",
                            role: .assistant
                        ))
                        self.isTyping = false
                    }
                    return // 🛑 INTERROMPIAMO QUI: Non viene fatta nessuna chiamata API
                }
                
                // 3. Ricevuta la risposta dal servizio, DE-CENSURIAMO i dati nel ViewModel
                let finalAnswer = restoreSensitiveData(in: rawAIAnswer)
                
                // 4. Aggiorniamo la UI in modo sicuro
                await MainActor.run {
                    self.messages.append(
                        Message(
                            text: finalAnswer,
                            role: .assistant,
                            censoredText: rawAIAnswer
                        )
                    )
                    self.isTyping = false
                }
                
            } catch let error as APIError {
                // Intercettiamo gli errori specifici delle nostre API (es. 401)
                await MainActor.run {
                    self.messages.append(Message(text: error.localizedDescription, role: .assistant))
                    self.isTyping = false
                }
            } catch {
                // Intercettiamo errori generici (es. no connessione internet)
                await MainActor.run {
                    self.messages.append(Message(text: "❌ Errore imprevisto: \(error.localizedDescription)", role: .assistant))
                    self.isTyping = false
                }
            }
        }
    }

    /*
    // MARK: - 4. Chiamata API
    func fetchAssistantResponse(censoredPrompt: String) {
        let savedApiKey = "REDACTED_API_KEY"
        self.isTyping = true
        
        Task {
            do {
                guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(savedApiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // 1. Creiamo la richiesta usando la TUA struct AIRequest
                let requestBody = AIRequest(
                    model: "llama-3.1-8b-instant",
                    messages: [
                        AIMessage(role: "system", content: "Sei un assistente legale. Rispondi in italiano in modo professionale."),
                        AIMessage(role: "user", content: censoredPrompt)
                    ]
                )
                
                request.httpBody = try JSONEncoder().encode(requestBody)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                // 2. Decodifichiamo usando la TUA struct AIResponse
                // Il percorso è: AIResponse -> choices (array) -> first -> message -> content
                let decodedResponse = try JSONDecoder().decode(AIResponse.self, from: data)
                let rawAIAnswer = decodedResponse.choices.first?.message.content ?? "Nessuna risposta ricevuta."
                
                // 3. 🔐 DE-CENSURA: Trasformiamo [NOME1] nel nome reale per l'utente
                let finalAnswer = restoreSensitiveData(in: rawAIAnswer)
                
                // 4. Aggiorniamo la UI
                let assistantMsg = Message(text: finalAnswer, role: .assistant)
                self.messages.append(assistantMsg)
                self.isTyping = false
                
            } catch {
                print("❌ Errore: \(error)")
                self.messages.append(Message(text: "Errore di connessione.", role: .assistant))
                self.isTyping = false
            }
        }
    }*/
    
    // MARK: - Helper: Gestione Alias
    private func getOrCreateAlias(for word: String, category: String) -> String {
        // Se l'abbiamo già censurata in questa conversazione, usiamo lo stesso alias
        if let existingAlias = originalToAlias[word] {
            return existingAlias
        }
        
        // Altrimenti ne creiamo uno nuovo
        let count = counters[category] ?? 1
        let alias = "[\(category)\(count)]" // Es: [NOME1]
        
        originalToAlias[word] = alias
        aliasToOriginal[alias] = word
        counters[category] = count + 1
        
        return alias
    }
    
    // MARK: - Helper: Ripristino Dati
    private func restoreSensitiveData(in apiResponse: String) -> String {
        var restoredText = apiResponse
        // Sostituiamo partendo dagli alias più lunghi per evitare bug (es: evitare che [NOME1] sovrascriva [NOME10])
        let sortedAliases = aliasToOriginal.keys.sorted { $0.count > $1.count }
        
        for alias in sortedAliases {
            if let originalWord = aliasToOriginal[alias] {
                restoredText = restoredText.replacingOccurrences(of: alias, with: originalWord)
            }
        }
        return restoredText
    }
    
    // MARK: - Motore AI (Modificato per restituire un Dizionario Parola -> Categoria)
    private func runAllAIModels(on text: String) async -> [String: String] {
        var foundEntities: [String: String] = [:]
        
        // 1. APPLE NLTagger
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.joinNames, .omitWhitespace]) { tag, range in
            let word = String(text[range])
            if tag == .personalName { foundEntities[word] = "NOME" }
            if tag == .placeName { foundEntities[word] = "LUOGO" }
            return true
        }
        
        // 2. DISTILBERT
        let distilBertEntities = extractEntitiesWithDistilBERT(text: text)
        for (word, category) in distilBertEntities {
            foundEntities[word] = category
        }
        
        return foundEntities
    }
    
    private func extractEntitiesWithDistilBERT(text: String) -> [(String, String)] {
        // Usa esattamente la tua funzione extractEntitiesWithDistilBERT originaria
        // Qui restituirai il tuo array [(word, mappedCategory)]
        return []
    }
}

