import SwiftUI

struct CodeBlockView: View {
    let code: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Code")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { didCopy = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { didCopy = false }
                    }
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Horizontal scrolling keeps long lines intact instead of wrapping them.
            ScrollView(.horizontal) {
                Text(code)
                    .font(.subheadline.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
