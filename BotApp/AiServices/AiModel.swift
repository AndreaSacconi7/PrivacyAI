// MARK: - OPENAI API MODELS and GROQ
struct AIRequest: Codable {
    let model: String
    let messages: [AIMessage]
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIResponse: Codable {
    let choices: [AIChoice]
}

struct AIChoice: Codable {
    let message: AIMessage
}

enum AIProvider: String, CaseIterable {
    case auto = "Rilevamento Automatico" // Utile come default
    case openai = "OpenAI (GPT)"
    case anthropic = "Anthropic (Claude)"
    case gemini = "Google (Gemini)"
    case groq = "Groq"
}

// MARK: - ANTHROPIC (CLAUDE) STRUCTS
struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String // Claude vuole il prompt di sistema separato dai messaggi!
    let messages: [AnthropicMessage]
}

struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

struct AnthropicContent: Codable {
    let text: String
}

// MARK: - GOOGLE GEMINI STRUCTS
struct GeminiRequest: Codable {
    let systemInstruction: GeminiSystemInstruction?
    let contents: [GeminiContent]
    
    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

struct GeminiSystemInstruction: Codable {
    let parts: [GeminiPart]
}

struct GeminiContent: Codable {
    let role: String
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
}
