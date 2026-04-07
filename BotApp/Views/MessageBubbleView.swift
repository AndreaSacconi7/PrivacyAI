// MessageView.swift
import SwiftUI

struct MessageView: View {
    @Binding var message: Message
    var onPrivacyTap: (() -> Void)? = nil
    var showCensored: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                AssistantMessageBody(
                    message: message,
                    onPrivacyTap: {
                        onPrivacyTap?()
                    },
                    showCensored: showCensored)
            } else {
                Spacer()
                UserMessageBubble(
                    message: $message,
                    onPrivacyTap: {
                        onPrivacyTap?() // Il passacarte!
                    },
                    showCensored: showCensored
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

/*
// Bolla messaggio utente (blu, a destra)
struct UserMessageBubble: View {
    let text: String
    var words: [String] {
            text.components(separatedBy: " ")
        }
    
    var body: some View {
        /*Text(text)
            .padding(12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(18)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .trailing)*/
        
        ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                            InteractiveWordView(word: word)
                        }
    }
}*/

// Bolla messaggio utente (blu, a destra) con Parole Interattive
struct UserMessageBubble: View {
    @Binding var message: Message
    
    // NUOVO: Aggiungiamo un'azione che passerà il testo verso l'alto
    var onPrivacyTap: () -> Void
    
    var showCensored: Bool
    
    var body: some View {
        /*// Dividiamo il testo dell'utente in parole
        let words = message
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }*/
        
        VStack {
            if #available(iOS 16.0, *) {
                FlowLayout(spacing: 4) {
                    // 1. Passa il binding dell'array ($message.tokens)
                    // 2. Estrai il binding del singolo token ($token)
                    ForEach($message.tokens) { $token in
                        
                        // 3. Passa il binding alla InteractiveWordView
                        InteractiveWordView(
                            token: $token,
                            isUserMessage: message.role == .user, // Se hai accesso al messaggio, usa il ruolo reale
                            showCensored: showCensored
                        )
                    }
                }
                // 1. IL TRUCCO MAGICO:
                // Se isReviewing è true -> Si possono cliccare le parole.
                // Se è false -> I click passano "attraverso" e le parole diventano intoccabili.
                .allowsHitTesting(message.isReviewing)
                
            } else {
                Text(message.text)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color(.darkGray))
        .cornerRadius(18)
        .frame(maxWidth: .infinity, alignment: message.isReviewing ? .center : .trailing)
        .padding(message.isReviewing ? .horizontal : .leading, message.isReviewing ? 20 : 40) // Evita che la bolla tocchi il bordo sinistro se il testo è lungo
        // 2. AGGIUNGIAMO IL MENU A PRESSIONE LUNGA (Context Menu)
        .contextMenu {
            if !message.isReviewing && !showCensored {
                Button {
                    // Quando l'utente clicca, avvisiamo la vista genitore!
                    onPrivacyTap()
                } label: {
                    Label("Privacy Message", systemImage: "lock.shield")
                }
                
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Copia Originale", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

// Corpo messaggio assistente formattato (senza bolla, a sinistra)
struct AssistantMessageBody: View {
    let message: Message
    var onPrivacyTap: () -> Void
    var showCensored: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Leggermente più spazio per respirare
            
            // Intestazione assistente
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue.opacity(0.8))
                Text("Assistente Gemini")
                    .font(.caption.weight(.semibold)) // Un po' più marcato
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            // 3. Usiamo message.text invece di text
            let sourceText = showCensored ? (message.censoredText ?? message.text) : message.text
            let (parts, codeBlocks) = parseTextAndCode(from: sourceText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<parts.count, id: \.self) { index in
                    // Testo Markdown
                    if !parts[index].isEmpty {
                        if let textPart = try? AttributedString(markdown: parts[index], options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(textPart)
                                .font(.body) // Font leggibile
                                .lineSpacing(4) // Spazio tra le righe per migliorare la lettura
                                .textSelection(.enabled)
                        } else {
                            Text(parts[index])
                        }
                    }
                    
                    // Blocco di codice
                    if index < codeBlocks.count {
                        CodeBlockView(code: codeBlocks[index])
                            .padding(.vertical, 4)
                    }
                }
            }

            // Pulsanti di Feedback
            HStack(spacing: 20) {
                Button(action: { /* Azione Like */ }) {
                    Image(systemName: "hand.thumbsup")
                }
                Button(action: { /* Azione Dislike */ }) {
                    Image(systemName: "hand.thumbsdown")
                }
                
                Spacer() // Spinge i pollici a sinistra
            }
            .font(.subheadline)
            .foregroundColor(.gray.opacity(0.8))
            .padding(.top, 5)
        }
        .padding(.horizontal, 16) // Padding generale
        .padding(.vertical, 12)
        // Colore di sfondo leggerissimo per staccare dal bianco/nero dello sfondo
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // 4. IL CONTEXT MENU!
        .contextMenu {
            if !message.isReviewing && !showCensored {
                Button {
                    onPrivacyTap()
                } label: {
                    Label("Privacy Message", systemImage: "lock.shield")
                }
            }
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copia Testo", systemImage: "doc.on.doc")
            }
        }
    }
    
    // Semplice funzione di parsing per separare testo markdown dai blocchi di codice
    private func parseTextAndCode(from input: String) -> ([String], [String]) {
        var textParts: [String] = []
        var codeBlocks: [String] = []
        
        let components = input.components(separatedBy: "```")
        
        for (index, component) in components.enumerated() {
            if index % 2 == 0 {
                // Parte di testo
                textParts.append(component.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                // Parte di codice
                // Rimuovere il nome del linguaggio (es. "swift\\n")
                var codeLines = component.components(separatedBy: .newlines)
                if codeLines.count > 1 && !codeLines[0].contains(" ") {
                    codeLines.removeFirst()
                }
                let cleanedCode = codeLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                codeBlocks.append(cleanedCode)
            }
        }
        
        return (textParts, codeBlocks)
    }
}
