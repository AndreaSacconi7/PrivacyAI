import SwiftUI

struct CodeBlockView: View {
    let code: String
    @State private var didCopy = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Intestazione
            HStack {
                Text("Codice")
                    .font(.caption2.monospaced())
                    .foregroundColor(.white)
                Spacer()
                
                // Tasto Copia interattivo
                Button(action: {
                    UIPasteboard.general.string = code
                    withAnimation { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { didCopy = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copiato!" : "Copia")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))

            // 🌟 La ScrollView Orizzontale per preservare l'ordine del codice!
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.subheadline.monospaced()) // Font da programmatore
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading) // Allinea tutto a sinistra
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(UIColor.systemGray6))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.systemGray6), lineWidth: 1)
        )
    }
}
