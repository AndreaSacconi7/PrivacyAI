import SwiftUI

struct PrivacyOverlayView: View {
    var message: Message
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // HEADER con titolo e bottone di chiusura
            HStack {
                // IL TASTO INDIETRO STILE APPLE
                Button(action: {
                    isShowing = false // Questo fa tornare indietro o chiude il pannello!
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold)) // Rende la freccia leggermente più spessa (stile iOS)
                        /*Text("Back")
                            .font(.body)*/
                    }
                    .foregroundColor(.blue) // Il colore interattivo standard di Apple
                }
                Spacer()
                
                Text("Privacy Text")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                Spacer()
            }
            .padding(.top, 20)
            
            Divider()
            
            ScrollView {
                MessageView(
                    message: .constant(message),
                    onPrivacyTap: {},
                    showCensored: true
                )
            }
            /*
            // TESTO CENSURATO
            ScrollView {
                FlowLayout(spacing: 4) {
                    ForEach(message.tokens) { token in
                        InteractiveWordView(
                            token: .constant(token),
                            isUserMessage: true,
                            showCensored: true // 👈 LA MAGIA È TUTTA QUI!
                        )
                    }
                }
                .allowsHitTesting(false)
            }*/
            
            Spacer()
        }
        .padding(.horizontal)
        // Occupa il 75% dello schermo
        .frame(width: UIScreen.main.bounds.width)
        .frame(maxHeight: .infinity)
        // Sfondo dinamico (chiaro/scuro) con una piccola ombra sul lato sinistro
        .background(Color(UIColor.systemBackground).shadow(color: .black.opacity(0.1), radius: 10, x: -5, y: 0)) 
    }
}
