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
    private var customDistilBERTModel: BertBase_NER_Uncased_EN_120MB?
    private var tokenizer: Tokenizer? // Assicurati di avere la classe Tokenizer nel progetto
    
    // Il "Caveau" dei Dati Sensibili
    private var originalToAlias: [String: String] = [:]
    private var aliasToOriginal: [String: String] = [:]
    private var counters: [String: Int] = ["NOME": 1, "LUOGO": 1, "ORG": 1, "GENERIC": 1]
    
    // Se quella sopra non funziona, prova questa (Variante B):
    let idToLabel: [Int: String] = [
        0: "O",
        1: "B-MISC",
        2: "I-MISC",
        3: "B-PER",
        4: "I-PER",
        5: "B-ORG",
        6: "I-ORG",
        7: "B-LOC",
        8: "I-LOC"
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
            // 1. Carica il modello Core ML a 8-bit compresso localmente
            let model = try await Task.detached(priority: .userInitiated) {
                try BertBase_NER_Uncased_EN_120MB(configuration: MLModelConfiguration())
            }.value
            
            self.customDistilBERTModel = model
            
            // 2. Chiede a Swift di collegarsi a Internet e scaricare il Tokenizer
            print("⏳ Download del Tokenizer da Internet in corso...")
            // Scarica il tokenizer modernizzato, a prova di crash su iOS!
            self.tokenizer = try await AutoTokenizer.from(pretrained: "Xenova/bert-base-uncased")
            
            self.isAIReady = true
            print("✅ Intelligenza Artificiale e Tokenizer pronti!")
            
        } catch {
            print("❌ Errore caricamento AI o Tokenizer: \(error)")
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
        
        print("founded categories: ")
        // 3. Mappiamo i risultati dell'AI sui nostri token
        for i in 0..<newPendingMessage.tokens.count {
            let word = newPendingMessage.tokens[i].text
            
            // Puliamo la parola da punteggiatura
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            
            // 💡 IL FIX: Abbassiamo le maiuscole solo per "bussare" al dizionario AI
            let wordForSearch = cleanWord.lowercased()
        
            if let categoryFoundByAI = aiResults[wordForSearch] {
                // Se l'AI ha trovato una corrispondenza, assegniamo la categoria al token
                print("Trovato match perfetto per: \(word) -> \(categoryFoundByAI)")
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
    
    private func runAllAIModels(on text: String) async -> [String: String] {
        var foundEntities: [String: String] = [:]
        
        // 1. REGEX (Priorità Alta)
        // Email, Telefoni, IBAN dovrebbero essere estratti qui.
        //let regexEntities = extractPIIWithRegex(text: text)
        //foundEntities.merge(regexEntities) { (current, _) in current }

        /*
        // 2. APPLE NLTagger (Veloce e ottimizzato per la lingua di sistema)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.joinNames, .omitWhitespace]) { tag, range in
            let word = String(text[range])
            if tag == .personalName { foundEntities[word] = "NOME" }
            else if tag == .placeName { foundEntities[word] = "LUOGO" }
            //else if tag == .organizationName { }
            return true
        }*/
        
        // 3. DISTILBERT (Solo per ciò che manca o per conferma)
        // Passa solo le parti di testo non ancora identificate se vuoi performance estreme,
        // oppure usalo per arricchire i risultati.
        let distilBertEntities = extractEntitiesWithDistilBERT(text: text)
        print(distilBertEntities)
        for (word, category) in distilBertEntities {
            // Aggiungi solo se non abbiamo già identificato la parola con Regex/NLTagger
            if foundEntities[word] == nil {
                foundEntities[word] = category
            }
        }
        
        return foundEntities
    }
    
    // MARK: - 7. Estrattore DistilBERT
    private func extractEntitiesWithDistilBERT(text: String) -> [(String, String)] {
        print("entrato su distilbert")
        guard let tokenizer = self.tokenizer, let model = self.customDistilBERTModel else {
            return []
        }
        
        print("eseguo bert")
        let maxLength = 128
        let numberOfClasses = 9
        let padTokenId: Int32 = 0
        
        // 1. Preparazione Input e Attention Mask
        var tokenIds = tokenizer.encode(text: text).map { Int32($0) }
        /*let testoMinuscolo = text.lowercased()
        var tokenIds = tokenizer.encode(text: testoMinuscolo).map { Int32($0) }*/
        // Aggiungi [CLS] (101) all'inizio se manca
        /*if tokenIds.first != 101 {
            tokenIds.insert(101, at: 0)
        }

        // Aggiungi [SEP] (102) alla fine (prima del padding) se manca
        if tokenIds.last != 102 {
            tokenIds.append(102)
        }*/
        
        var attentionMask = Array(repeating: Int32(1), count: tokenIds.count)
        
        if tokenIds.count > maxLength {
            tokenIds = Array(tokenIds.prefix(maxLength))
            attentionMask = Array(attentionMask.prefix(maxLength))
        } else {
            let paddingCount = maxLength - tokenIds.count
            tokenIds.append(contentsOf: Array(repeating: padTokenId, count: paddingCount))
            attentionMask.append(contentsOf: Array(repeating: Int32(0), count: paddingCount))
        }
        
        // 2. Creazione MLMultiArray
        guard let inputIdsArray = try? MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32),
              let attentionMaskArray = try? MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32) else {
            print("❌ Errore: Impossibile allocare MLMultiArray")
            return []
        }
        
        // Scrittura veloce e sicura (perché gli array li abbiamo appena inizializzati noi come .int32 continui)
        let inputIdsPointer = inputIdsArray.dataPointer.bindMemory(to: Int32.self, capacity: maxLength)
        let attentionMaskPointer = attentionMaskArray.dataPointer.bindMemory(to: Int32.self, capacity: maxLength)
        
        for i in 0..<maxLength {
            inputIdsPointer[i] = tokenIds[i]
            attentionMaskPointer[i] = attentionMask[i]
        }
        
        var foundEntities: [(String, String)] = []
        
        do {
            // 3. Predizione
            let predictionInput = BertBase_NER_Uncased_EN_120MBInput(input_ids: inputIdsArray, attention_mask: attentionMaskArray)
            let predictionOutput = try model.prediction(input: predictionInput)
            
            let outputTensor = predictionOutput.var_1004
            
            var currentEntityTokenIds: [Int] = []
            var currentCategory = ""
            
            for i in 0..<maxLength {
                if attentionMask[i] == 0 { break } // Salta il padding
                
                var maxScore: Float = -Float.greatestFiniteMagnitude
                var bestClassIndex = 0
                
                // LETTURA SICURA
                for classIndex in 0..<numberOfClasses {
                    let pointer = [0, NSNumber(value: i), NSNumber(value: classIndex)]
                    let score = outputTensor[pointer].floatValue
                    if score > maxScore {
                        maxScore = score
                        bestClassIndex = classIndex
                    }
                }
                
                let label = idToLabel[bestClassIndex] ?? "O"
                
                // LA LOGICA APPIATTITA (Senza Closure)
                if label.starts(with: "B-") {
                    // 1. Se c'era già un'entità in memoria, salvala prima di iniziare quella nuova!
                    if !currentEntityTokenIds.isEmpty {
                        let decodedString = tokenizer.decode(tokens: currentEntityTokenIds).trimmingCharacters(in: .whitespacesAndNewlines)
                        foundEntities.append((decodedString, currentCategory))
                    }
                    
                    // 2. Inizia a tracciare la nuova entità
                    currentEntityTokenIds = [Int(tokenIds[i])]
                    currentCategory = String(label.dropFirst(2))
                    
                } else if label.starts(with: "I-") {
                    // È il pezzo successivo di un nome (es. il cognome)
                    currentEntityTokenIds.append(Int(tokenIds[i]))
                    
                } else {
                    // È una parola normale ("O"). Se avevamo un'entità in sospeso, salviamola!
                    if !currentEntityTokenIds.isEmpty {
                        let decodedString = tokenizer.decode(tokens: currentEntityTokenIds).trimmingCharacters(in: .whitespacesAndNewlines)
                        foundEntities.append((decodedString, currentCategory))
                        currentEntityTokenIds.removeAll() // Svuota per la prossima
                    }
                }
            }
            
            // FINE DEL LOOP: Salva l'ultimissima entità se la frase finisce proprio con un nome
            if !currentEntityTokenIds.isEmpty {
                let decodedString = tokenizer.decode(tokens: currentEntityTokenIds).trimmingCharacters(in: .whitespacesAndNewlines)
                foundEntities.append((decodedString, currentCategory))
            }
            
        } catch {
            print("❌ Errore predizione Core ML: \(error.localizedDescription)")
        }
        
        // --- PRINT DI CONTROLLO FINALE ---
        print("🎯 Entità estratte prima della mappatura: \(foundEntities)")
        // ---------------------------------
        
        // 4. Mappatura
        return foundEntities.map { word, category in
            let mappedCategory: String
            switch category {
            case "PER": mappedCategory = "NOME"
            case "LOC": mappedCategory = "LUOGO"
            case "ORG": mappedCategory = "ORG"
            default: mappedCategory = "GENERIC"
            }
            return (word, mappedCategory)
        }
    }
}

