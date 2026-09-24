import Foundation

struct LLMChatMessage: Equatable {
    let role: MessageRole
    let content: String
}

/// Sends an already-pseudonymized conversation to the configured provider.
struct LLMClient {
    let provider: LLMProvider
    let apiKey: String
    let model: String
    var urlSession: URLSession = .shared

    static let systemPrompt = """
    You are a helpful assistant. To protect the user's privacy, some personal details in \
    their messages were replaced with placeholders such as [PERSON_1], [LOCATION_2] or [ORG_1]. \
    Treat each placeholder as the real name it stands for, reuse the exact placeholder whenever \
    you refer to it, and never ask what it stands for. Reply in the same language as the user.
    """

    func complete(_ conversation: [LLMChatMessage]) async throws -> String {
        let messages = Self.mergingConsecutiveRoles(conversation)
        let reply: String?

        switch provider {
        case .openAI:
            reply = try await completeOpenAICompatible(messages, endpoint: "https://api.openai.com/v1/chat/completions")
        case .groq:
            reply = try await completeOpenAICompatible(messages, endpoint: "https://api.groq.com/openai/v1/chat/completions")
        case .anthropic:
            reply = try await completeAnthropic(messages)
        case .gemini:
            reply = try await completeGemini(messages)
        }

        guard let reply, !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyResponse
        }
        return reply
    }

    /// Providers expect user and assistant turns to alternate. A user message
    /// that failed to get a reply is merged with the next one.
    static func mergingConsecutiveRoles(_ messages: [LLMChatMessage]) -> [LLMChatMessage] {
        messages.reduce(into: []) { merged, message in
            if let last = merged.last, last.role == message.role {
                merged[merged.count - 1] = LLMChatMessage(role: last.role, content: last.content + "\n\n" + message.content)
            } else {
                merged.append(message)
            }
        }
    }

    // MARK: - Providers

    private func completeOpenAICompatible(_ messages: [LLMChatMessage], endpoint: String) async throws -> String? {
        let body = OpenAIChatRequest(
            model: model,
            messages: [.init(role: "system", content: Self.systemPrompt)]
                + messages.map { .init(role: $0.role.rawValue, content: $0.content) }
        )
        let request = try makeRequest(endpoint, body: body, headers: ["Authorization": "Bearer \(apiKey)"])
        let response: OpenAIChatResponse = try await send(request)
        return response.choices.first?.message.content
    }

    private func completeAnthropic(_ messages: [LLMChatMessage]) async throws -> String? {
        let body = AnthropicMessagesRequest(
            model: model,
            maxTokens: 2048,
            system: Self.systemPrompt,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) }
        )
        let request = try makeRequest(
            "https://api.anthropic.com/v1/messages",
            body: body,
            headers: ["x-api-key": apiKey, "anthropic-version": "2023-06-01"]
        )
        let response: AnthropicMessagesResponse = try await send(request)
        return response.content.compactMap(\.text).joined()
    }

    private func completeGemini(_ messages: [LLMChatMessage]) async throws -> String? {
        let body = GeminiGenerateRequest(
            systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: Self.systemPrompt)]),
            contents: messages.map {
                GeminiContent(role: $0.role == .user ? "user" : "model", parts: [GeminiPart(text: $0.content)])
            }
        )
        let request = try makeRequest(
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent",
            body: body,
            headers: ["x-goog-api-key": apiKey]
        )
        let response: GeminiGenerateResponse = try await send(request)
        return response.candidates?.first?.content?.parts.compactMap(\.text).joined()
    }

    // MARK: - HTTP

    private func makeRequest(_ endpoint: String, body: some Encodable, headers: [String: String]) throws -> URLRequest {
        guard let url = URL(string: endpoint) else { throw LLMError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LLMError(statusCode: httpResponse.statusCode, body: data)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw LLMError.invalidResponse
        }
    }
}
