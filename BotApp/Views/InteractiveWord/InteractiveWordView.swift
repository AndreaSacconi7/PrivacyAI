import SwiftUI

struct InteractiveWordView: View {
    // 1. Invece della stringa e dello stato locale, passiamo il BINDING al token completo
    @Binding var token: WordToken
    var isUserMessage: Bool = false
    var showCensored: Bool = false
    
    var body: some View {
        Menu {
            // 2. I bottoni ora modificano direttamente la categoria DENTRO il token!
            Button("Nome") { token.category = "NOME" }
            Button("Luogo") { token.category = "LUOGO" }
            Button("Verbo") { token.category = "VERBO" }
            Divider()
            Button("Rimuovi tag", role: .destructive) { token.category = nil }
        } label: {
            // 3. Leggiamo il testo direttamente dal token
            Text(showCensored ? (token.censoredText ?? token.text) : token.text)
                .font(.body)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .cornerRadius(6)
                .foregroundColor(textColor)
                .lineLimit(1) // Vietato andare a capo su se stessa
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    // 4. Aggiorniamo le computed properties per controllare token.category
    private var textColor: Color {
        if token.category != nil { return .white } // Sempre bianco se taggato
        return isUserMessage ? .white : .primary     // Bianco nell'utente, Standard nell'IA
    }
    
    private var backgroundColor: Color {
        switch token.category {
        case "NOME": return isUserMessage ? .indigo : .blue
        case "LUOGO": return isUserMessage ? .mint : .green
        case "VERBO": return .orange // L'arancione sta bene su entrambi
        default: return Color.clear
        }
    }
}

/*
struct InteractiveWordView: View {
    let word: String
    var isUserMessage: Bool = false // <-- Aggiunto per capire dove si trova la parola
    
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        Menu {
            Button("Nome") { selectedCategory = "Nome" }
            Button("Luogo") { selectedCategory = "Luogo" }
            Button("Verbo") { selectedCategory = "Verbo" }
            Divider()
            Button("Rimuovi tag", role: .destructive) { selectedCategory = nil }
        } label: {
            Text(word)
                .font(.body)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .cornerRadius(6)
                // Se è selezionata o se è un messaggio dell'utente, il testo è bianco
                .foregroundColor(textColor)
        }
    }
    
    // Gestione dinamica del colore del testo
    private var textColor: Color {
        if selectedCategory != nil { return .white } // Sempre bianco se taggato
        return isUserMessage ? .white : .primary     // Bianco nell'utente, Standard nell'IA
    }
    
    // Gestione dinamica dello sfondo del tag
    private var backgroundColor: Color {
        switch selectedCategory {
        case "Nome": return isUserMessage ? .indigo : .blue
        case "Luogo": return isUserMessage ? .mint : .green
        case "Verbo": return .orange // L'arancione sta bene su entrambi
        default: return Color.clear
        }
    }
}*/
