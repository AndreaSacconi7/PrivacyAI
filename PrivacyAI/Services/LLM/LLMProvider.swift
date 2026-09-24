import Foundation

enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case gemini
    case groq

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Google Gemini"
        case .groq: return "Groq"
        }
    }

    /// Used when the user has not typed a model name in Settings.
    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-5.4-mini"
        case .anthropic: return "claude-sonnet-5"
        case .gemini: return "gemini-3.8-flash"
        case .groq: return "openai/gpt-oss-20b"
        }
    }

    /// Guesses the provider from the API key format.
    static func detect(fromAPIKey apiKey: String) -> LLMProvider? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // "sk-ant-" must be checked before the generic OpenAI "sk-" prefix.
        if key.hasPrefix("sk-ant-") { return .anthropic }
        if key.hasPrefix("gsk_") { return .groq }
        if key.hasPrefix("AIza") { return .gemini }
        if key.hasPrefix("sk-") { return .openAI }
        return nil
    }
}
