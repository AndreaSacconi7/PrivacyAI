import Foundation

enum LLMError: LocalizedError, Equatable {
    case missingAPIKey
    case unknownProvider
    case invalidAPIKey
    case rateLimited
    case server(statusCode: Int, message: String?)
    case invalidResponse
    case emptyResponse

    /// Maps an HTTP error response to a user-facing error.
    init(statusCode: Int, body: Data) {
        switch statusCode {
        case 401, 403:
            self = .invalidAPIKey
        case 429:
            self = .rateLimited
        default:
            // OpenAI, Anthropic and Gemini all return `{"error": {"message": "..."}}`.
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.error?.message
            self = .server(statusCode: statusCode, message: message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add an API key in Settings to start chatting."
        case .unknownProvider:
            return "Couldn't tell which provider this API key belongs to. Pick the provider manually in Settings."
        case .invalidAPIKey:
            return "The API key was rejected. Check that it is correct and still active."
        case .rateLimited:
            return "The provider is rate limiting requests. Try again in a moment."
        case let .server(statusCode, message):
            return "The provider returned an error (HTTP \(statusCode))" + (message.map { ": \($0)" } ?? ".")
        case .invalidResponse:
            return "The provider sent a response the app could not read."
        case .emptyResponse:
            return "The provider sent an empty response."
        }
    }

    private struct ErrorBody: Decodable {
        struct Detail: Decodable { let message: String? }
        let error: Detail?
    }
}
