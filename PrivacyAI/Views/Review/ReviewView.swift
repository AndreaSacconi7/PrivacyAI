import SwiftUI

/// Shown before a message is sent: the user checks the words the model
/// tagged and can add or remove tags.
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message: Message
    let recognizerState: ChatViewModel.RecognizerState
    let onSend: (Message) -> Void

    init(message: Message, recognizerState: ChatViewModel.RecognizerState, onSend: @escaping (Message) -> Void) {
        _message = State(initialValue: message)
        self.recognizerState = recognizerState
        self.onSend = onSend
    }

    private var taggedCount: Int {
        message.tokens.filter { $0.category != nil }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                GeometryReader { proxy in
                    ScrollView {
                        MessageView(message: $message)
                            // Center the bubble vertically when it is shorter than the screen.
                            .frame(minHeight: proxy.size.height)
                    }
                }

                legend

                ZStack {
                    HStack {
                        CircleIconButton(systemImage: "chevron.left", background: Color(.tertiarySystemBackground)) {
                            dismiss()
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    CircleIconButton(systemImage: "arrow.up", background: .primary, isLarge: true) {
                        onSend(message)
                        dismiss()
                    }
                    .accessibilityLabel("Send")
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 20)
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(taggedCount == 0
                 ? "No personal details found."
                 : "\(taggedCount) word\(taggedCount == 1 ? "" : "s") will be replaced before sending.")
                .font(.subheadline.weight(.semibold))
            Text("Tap any word to tag or untag it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if case .unavailable = recognizerState {
                Label("On-device model unavailable: tag words manually.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(EntityCategory.allCases) { category in
                HStack(spacing: 4) {
                    Circle().fill(category.color).frame(width: 8, height: 8)
                    Text(category.displayName)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

struct CircleIconButton: View {
    let systemImage: String
    let background: Color
    var isLarge = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isLarge ? 20 : 16, weight: isLarge ? .bold : .regular))
                .foregroundStyle(isLarge ? Color(.systemBackground) : .primary)
                .frame(width: isLarge ? 50 : 36, height: isLarge ? 50 : 36)
                .background(background, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
        }
    }
}
