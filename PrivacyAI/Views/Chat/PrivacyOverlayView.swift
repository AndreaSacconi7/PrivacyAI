import SwiftUI

/// Side panel showing a message exactly as the LLM saw it.
struct PrivacyOverlayView: View {
    let message: Message?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(message?.role == .assistant ? "Received from the AI" : "Sent to the AI")
                    .font(.headline)
                Spacer()
                // Balances the close button so the title stays centered.
                Image(systemName: "chevron.left").hidden()
            }
            .padding(.top, 20)

            Text("Placeholders stand in for the personal details that never left your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            if let message {
                ScrollView {
                    MessageView(message: .constant(message), showMasked: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .frame(width: UIScreen.main.bounds.width)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
