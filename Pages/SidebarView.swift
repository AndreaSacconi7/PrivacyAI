import SwiftUI

struct SidebarView: View {
    @Binding var isShowing: Bool
    @ObservedObject var store: ChatStore
    let onSettingsTap: () -> Void
    
    // Dati finti per l'esempio. Qui un domani leggerai dal tuo database/CoreData
    let chatsOggi = ["Censura documenti legali", "Revisione contratto d'affitto"]
    let chatsIeri = ["Analisi privacy policy", "Come usare SwiftUI"]
    let chatsMese = ["Idee per il logo", "Scrivi una mail formale"]
    
    let onChatSelected: (ChatSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // HEADER: Icona Settings in alto a destra
            HStack {
                Spacer()
                Button(action: {
                    // 2. Chiamiamo l'azione quando si tocca l'ingranaggio
                    onSettingsTap()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // LISTA CRONOLOGIA CHAT
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    if store.savedChats.isEmpty {
                            Text("Nessuna chat salvata")
                                .foregroundColor(.gray)
                                .padding()
                    } else {
                        // 2. Cicliamo sulle chat reali che abbiamo salvato
                        ChatHistorySectionReal(title: "Recenti", sessions: store.savedChats, onSelect: onChatSelected)
                    }
                    
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        // Il menu occuperà l'80% della larghezza dello schermo
        //.frame(width: UIScreen.main.bounds.width * 0.8)
        .frame(width: UIScreen.main.bounds.width)
        .frame(maxHeight: .infinity)
        // Usa il colore di sistema in modo che si adatti a Dark Mode / Light Mode
        .background(Color(UIColor.systemBackground)) 
    }
}

// Nuovo Sotto-componente che accetta le sessioni vere
struct ChatHistorySectionReal: View {
    let title: String
    let sessions: [ChatSession]
    let onSelect: (ChatSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ForEach(sessions) { session in
                Button(action: {
                    // 4. Quando si tocca il bottone, inviamo la sessione verso l'alto!
                    onSelect(session)
                }) {
                    Text(session.title)
                        // ... (stile testo invariato)
                }
            }
        }
    }
}
