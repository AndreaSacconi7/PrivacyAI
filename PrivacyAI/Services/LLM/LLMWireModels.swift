import Foundation

// Request and response bodies for each provider's HTTP API.

// MARK: - OpenAI-compatible (OpenAI, Groq)

struct OpenAIChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
}

struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }

    let choices: [Choice]
}

// MARK: - Anthropic

struct AnthropicMessagesRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

struct AnthropicMessagesResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    let content: [ContentBlock]
}

// MARK: - Google Gemini

struct GeminiPart: Codable {
    let text: String?
}

struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

struct GeminiGenerateRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
    }
}

struct GeminiGenerateResponse: Decodable {
    struct Candidate: Decodable { let content: GeminiContent? }
    let candidates: [Candidate]?
}
