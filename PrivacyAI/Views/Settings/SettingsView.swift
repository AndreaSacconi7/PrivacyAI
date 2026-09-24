import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let recognizerState: ChatViewModel.RecognizerState

    @State private var apiKey = LLMSettings.apiKey
    /// Raw value of the chosen `LLMProvider`, or "" for auto-detection.
    @AppStorage(LLMSettings.providerDefaultsKey) private var providerRawValue = ""

    private var effectiveProvider: LLMProvider? {
        LLMProvider(rawValue: providerRawValue) ?? LLMProvider.detect(fromAPIKey: apiKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { LLMSettings.apiKey = apiKey }

                    Picker("Provider", selection: $providerRawValue) {
                        Text("Auto-detect").tag("")
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }

                    if let provider = effectiveProvider {
                        ModelField(provider: provider)
                            .id(provider)
                    }
                } header: {
                    Text("AI provider")
                } footer: {
                    Text(providerFooter)
                }

                Section("Privacy") {
                    LabeledContent("On-device model") {
                        switch recognizerState {
                        case .loading: Text("Loading…")
                        case .ready: Text("Ready").foregroundStyle(.green)
                        case .unavailable: Text("Not available").foregroundStyle(.orange)
                        }
                    }
                    if case let .unavailable(reason) = recognizerState {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Your API key is stored in the iOS Keychain. Chats are stored only on this device. The AI provider only receives text with placeholders.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: Self.appVersion)
                    Link(destination: URL(string: "https://github.com/AndreaSacconi7/PrivacyAI_app")!) {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var providerFooter: String {
        if !providerRawValue.isEmpty || apiKey.isEmpty {
            return "Supports OpenAI, Anthropic, Google Gemini and Groq keys."
        }
        if let detected = LLMProvider.detect(fromAPIKey: apiKey) {
            return "Detected \(detected.displayName) from the key format."
        }
        return "Couldn't detect the provider from this key. Pick it manually."
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

/// Optional model override. Empty means the provider's default model.
private struct ModelField: View {
    let provider: LLMProvider
    @AppStorage private var model: String

    init(provider: LLMProvider) {
        self.provider = provider
        _model = AppStorage(wrappedValue: "", LLMSettings.modelDefaultsKey(for: provider))
    }

    var body: some View {
        LabeledContent("Model") {
            TextField(provider.defaultModel, text: $model)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}
