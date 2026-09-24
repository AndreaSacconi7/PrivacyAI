import Foundation

/// User configuration for the LLM connection. The API key lives in the
/// Keychain; the non-secret preferences live in `UserDefaults`.
enum LLMSettings {
    static let providerDefaultsKey = "llm.provider"
    private static let apiKeyAccount = "llm-api-key"

    static var apiKey: String {
        get { KeychainStore.string(for: apiKeyAccount) ?? "" }
        set { KeychainStore.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: apiKeyAccount) }
    }

    /// The provider picked in Settings, or nil for auto-detection.
    static var selectedProvider: LLMProvider? {
        UserDefaults.standard.string(forKey: providerDefaultsKey).flatMap(LLMProvider.init(rawValue:))
    }

    static func modelDefaultsKey(for provider: LLMProvider) -> String {
        "llm.model.\(provider.rawValue)"
    }

    static func model(for provider: LLMProvider) -> String {
        let custom = UserDefaults.standard.string(forKey: modelDefaultsKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? provider.defaultModel : custom
    }

    static func makeClient() throws -> LLMClient {
        let key = apiKey
        guard !key.isEmpty else { throw LLMError.missingAPIKey }
        guard let provider = selectedProvider ?? LLMProvider.detect(fromAPIKey: key) else {
            throw LLMError.unknownProvider
        }
        return LLMClient(provider: provider, apiKey: key, model: model(for: provider))
    }

    /// Earlier versions stored the key in plain `UserDefaults`. Move it to the
    /// Keychain and drop the old entries.
    static func migrateLegacySettings() {
        let defaults = UserDefaults.standard
        if let legacyKey = defaults.string(forKey: "user_api_key"), !legacyKey.isEmpty, apiKey.isEmpty {
            apiKey = legacyKey
        }
        defaults.removeObject(forKey: "user_api_key")
        defaults.removeObject(forKey: "selected_provider")
    }
}
