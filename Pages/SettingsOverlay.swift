import SwiftUI

struct SettingsOverlay: View {
    // 1. Stato per le preferenze dell'utente
    @State private var isDarkMode = true
    @State private var isHapticEnabled = true
    @State private var selectedLanguage = "Italiano"
    let languages = ["Italiano", "English", "Español", "Deutsch"]
    
    @AppStorage("user_api_key") private var apiKey: String = ""
    // NUOVO: Salviamo esplicitamente la scelta del provider!
    @AppStorage("selected_provider") private var selectedProvider: AIProvider = .auto

    // 2. Azione per chiudere l'overlay
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            // Usa 'Form' per ottenere il look raggruppato e pulito delle impostazioni di ChatGPT
            Form {
                
                // SEZIONE 1: ACCOUNT
                Section(header: Text("Account")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        VStack(alignment: .leading) {
                            Text("Mario Rossi")
                                .font(.headline)
                            Text("mario.rossi@email.com")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    NavigationLink {
                        Text("Dettagli Piano")
                    } label: {
                        // CORRETTO: systemImage al posto di systemName
                        Label("Il tuo piano: Premium", systemImage: "creditcard")
                    }
                }
                
                // SEZIONE 2: PREFERENZE APP
                Section(header: Text("Preferenze App")) {
                    // Tema (Dark Mode)
                    Toggle(isOn: $isDarkMode) {
                        Label("Tema Scuro", systemImage: "moon.fill")
                    }
                    
                    // Feedback Aptico
                    Toggle(isOn: $isHapticEnabled) {
                        Label("Feedback Aptico", systemImage: "waveform")
                    }
                    
                    // Lingua (con Menu a tendina)
                    Picker(selection: $selectedLanguage, label: Label("Lingua", systemImage: "globe")) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    .pickerStyle(.navigationLink) // Stile simile a ChatGPT
                }
                
                // SEZIONE 3: AI MODEL
                Section(header: Text("Modello AI")) {
                    NavigationLink(destination: Text("Dettagli Privacy")) {
                        Label("Gestione Privacy", systemImage: "shield.checkered")
                    }
                    NavigationLink(destination: Text("Dettagli Modello")) {
                        Label("Versione BERT: v1.2", systemImage: "cpu")
                    }
                }
                
                Section {
                    SecureField("Incolla la tua API Key qui...", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        // LA MAGIA: Quando l'utente incolla, proviamo a indovinare
                        .onChange(of: apiKey) { newValue in
                            autoDetectProvider(from: newValue)
                        }
                    
                    // IL SALVAGENTE: Il menu a tendina per l'override manuale
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    
                } header: {
                    Text("Configurazione AI")
                } footer: {
                    Text("Se il rilevamento automatico fallisce, puoi forzare manualmente il provider corretto dal menu.")
                }
                
                // SEZIONE 4: INFO & SUPPORTO
                Section(header: Text("Info & Supporto")) {
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Label("Centro Aiuto", systemImage: "questionmark.circle")
                    }
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Label("Termini di Servizio", systemImage: "doc.text")
                    }
                }
                
                // SEZIONE 5: AZIONI DESTRO (LOG OUT)
                Section {
                    Button(action: {
                        print("Esecuzione Log Out...")
                        onDismiss()
                    }) {
                        Text("Log Out")
                            .fontWeight(.bold)
                            .foregroundColor(.red) // Rosso "Destructive"
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // FOOTER
                Section {
                    Text("PrivacyAI per iOS • Versione 1.0.0 (42)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Bottone "Fatto" per chiudere
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fatto") {
                        onDismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    // La funzione che "tenta" di indovinare, ma senza rompere nulla se sbaglia
    private func autoDetectProvider(from key: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Se l'utente svuota il campo, torniamo in Auto
        if cleanKey.isEmpty {
            selectedProvider = .auto
            return
        }
        
        // Se l'utente aveva GIÀ fatto una scelta manuale, non gliela sovrascriviamo
        if selectedProvider != .auto { return }
        
        // Tentiamo l'indovinello
        if cleanKey.hasPrefix("sk-ant-") {
            selectedProvider = .anthropic
        } else if cleanKey.hasPrefix("sk-") {
            selectedProvider = .openai
        } else if cleanKey.hasPrefix("AIza") {
            selectedProvider = .gemini
        } else if cleanKey.hasPrefix("gsk") {
            selectedProvider = .groq
        }
    }
}
