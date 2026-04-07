//
//  InputBarView.swift
//  BotApp
//
//  Created by Andrea Sacconi on 28/03/26.
//


// InputBarView.swift
import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSendMessage: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom) {
            // Campo di testo espandibile ( axis: .vertical)
            TextField("Messaggio...", text: $text, axis: .vertical)
                .focused($isFocused)
                .padding(10)
                .lineLimit(1...5) // Si espande fino a 5 linee
                .background(Color(.systemGray6))
                .cornerRadius(22)
            
            // Pulsante di invio freccia blu (SF Symbol)
            Button(action: onSendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 34, height: 34)
                    .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .padding(.leading, 8)
            .padding(.bottom, 2)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty) // Disabilitato se vuoto
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(
            Divider(), alignment: .top // Sottile linea di divisione in alto
        )
    }
}