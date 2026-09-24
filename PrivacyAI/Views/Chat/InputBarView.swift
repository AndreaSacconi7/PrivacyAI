import SwiftUI

struct InputBarView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var isDisabled = false
    let onSend: () -> Void

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom) {
            TextField("Message", text: $text, axis: .vertical)
                .focused($isFocused)
                .lineLimit(1...5)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
            .padding(.leading, 8)
            .padding(.bottom, 2)
            .accessibilityLabel("Review and send")
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }
}
