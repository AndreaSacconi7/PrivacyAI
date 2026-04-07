import Foundation

class AIApiService {
    // Singleton: ci permette di usare il servizio ovunque senza ricrearlo
    static let shared = AIApiService()
    private init() {}
    
    // MARK: - OPENAI & GROQ
    func fetchOpenAIFormat(prompt: String, apiKey: String, endpoint: String, model: String) async throws -> String {
        guard let url = URL(string: endpoint) else { throw APIError.badResponse }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AIRequest(
            model: model,
            messages: [
                AIMessage(role: "system", content: "Sei un assistente legale. Rispondi in italiano in modo professionale."),
                AIMessage(role: "user", content: prompt)
            ]
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.badResponse }
        
        if httpResponse.statusCode == 401 {
            throw APIError.invalidKey("API Key non valida, errata o scaduta.")
        } else if httpResponse.statusCode != 200 {
            throw APIError.badResponse
        }
        
        let decodedResponse = try JSONDecoder().decode(AIResponse.self, from: data)
        return decodedResponse.choices.first?.message.content ?? "Nessuna risposta ricevuta."
    }
    
    // MARK: - ANTHROPIC (CLAUDE)
    func fetchAnthropic(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw APIError.badResponse }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        
        let requestBody = AnthropicRequest(
            model: "claude-3-5-sonnet-20241022",
            max_tokens: 1024,
            system: "Sei un assistente legale. Rispondi in italiano in modo professionale.",
            messages: [AnthropicMessage(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.badResponse }
        
        if httpResponse.statusCode == 401 {
            throw APIError.invalidKey("API Key Anthropic non valida.")
        } else if httpResponse.statusCode != 200 {
            throw APIError.badResponse
        }
        
        let decodedResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decodedResponse.content.first?.text ?? "Nessuna risposta ricevuta."
    }
    
    // MARK: - GOOGLE GEMINI
    func fetchGemini(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent") else { throw APIError.badResponse }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            systemInstruction: GeminiSystemInstruction(parts: [GeminiPart(text: "Sei un assistente legale. Rispondi in italiano in modo professionale.")]),
            contents: [GeminiContent(role: "user", parts: [GeminiPart(text: prompt)])]
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.badResponse }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
            throw APIError.invalidKey("API Key di Google Gemini non valida o formato errato.")
        } else if httpResponse.statusCode != 200 {
            throw APIError.badResponse
        }
        
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decodedResponse.candidates?.first?.content?.parts.first?.text ?? "Nessuna risposta ricevuta."
    }
}
