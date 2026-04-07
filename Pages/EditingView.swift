// MARK: - Pagina Principale
import SwiftUI
// Componente per i pulsanti personalizzati con cornice quadrata viola
struct CustomIconButton: View {
    let iconName: String
    let buttonColor: Color
    var isLarge: Bool = false
    let action: () -> Void // Sempre così, universale

    var body: some View {
        ZStack {
            // Pulsante circolare
            Button(action: {
                // Azione del pulsante
                action()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: isLarge ? 50 : 36, height: isLarge ? 50 : 36)
                        // Ombra per dare profondità
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)

                    // Icona
                    Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                        .fontWeight(buttonColor == .primary ? .bold : .light)
                        .frame(width: isLarge ? 20 : 16, height: isLarge ? 20 : 16)
                        .foregroundColor(buttonColor == .primary ? Color(UIColor.systemBackground) : .primary)
                }
            }
        }
    }
}

struct ReviewView: View {
    // Permette di chiudere questa pagina (il .sheet) programmaticamente
    @Environment(\.dismiss) var dismiss
    
    @State var pendingMessage: Message
    
    // La chiusura (closure) che avvisa la ChatView che abbiamo finito
    var onSend: (Message) -> Void;
    
    
    // ... i tuoi colori ...

    var body: some View {
        NavigationView {
            VStack {
                GeometryReader { proxy in
                                ScrollView {
                                    VStack {
                                        Spacer() // Spinge il messaggio verso il basso
                                        
                                        MessageView(message: $pendingMessage)
                                            .id(pendingMessage.id)
                                        
                                        Spacer() // Spinge il messaggio verso l'alto
                                    }
                                    // Forziamo il contenuto a prendere tutta la larghezza
                                    .frame(width: proxy.size.width)
                                    // Il trucco: l'altezza minima è quella di tutto lo schermo!
                                    // In questo modo i due Spacer() interni possono fare il loro lavoro e centrare la bolla.
                                    .frame(minHeight: proxy.size.height)
                                }
                            }
        
                /*
                // Mostriamo il vero testo appena scritto
                VStack(alignment: .leading, spacing: 5) {
                    Text(textToReview) // QUI MOSTRI IL TESTO REALE
                        .foregroundColor(.white.opacity(0.8))
                        .font(.body)
                }
                .padding(30)
                .background(Color(white: 0.2))
                .cornerRadius(30)
                .padding(.horizontal, 40)
                */

                // Controlli in basso
                ZStack {
                    // LIVELLO 1: Elementi allineati ai bordi
                    HStack {
                        // Tasto Indietro ancorato a sinistra
                        CustomIconButton(
                            iconName: "chevron.left",
                            buttonColor: Color(UIColor.tertiarySystemBackground),
                            action: {
                                dismiss()
                            }
                        )
                        
                        Spacer() // Questo spacer spinge la chevron tutta a sinistra
                        
                        // (Opzionale) Se vuoi rimettere l'AvatarView, puoi metterlo qui,
                        // e lo Spacer lo spingerà tutto a destra!
                        // AvatarView()
                    }
                    
                    // LIVELLO 2: Tasto Invio ancorato al centro assoluto dello ZStack
                    CustomIconButton(
                        iconName: "arrow.up",
                        buttonColor: .primary,
                        isLarge: true,
                        action: {
                            onSend(pendingMessage)
                            dismiss()
                        }
                    )
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 50)
            }
            // Nav Bar
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Review") // Titolo centrato
        }
    }
}
/*
// MARK: - Anteprima
struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Passiamo un testo finto e un'azione vuota solo per vedere la grafica
        ReviewView(
            textToReview: "Can you explain that Marco lives in milan. Can you explain that Marco lives in milan.",
            
            onSend: { testoSimulato in
                // Questo print si vedrà solo nella console se provi il bottone nell'anteprima
                print("L'utente ha premuto invio con il testo: \(testoSimulato)")
            }
        )
    }
}
*/
