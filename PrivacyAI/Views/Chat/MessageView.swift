import SwiftUI

struct MessageView: View {
    @Binding var message: Message
    /// Show the placeholders the LLM saw instead of the real values.
    var showMasked = false
    /// Opens the privacy panel for this message.
    var onInspect: (() -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            switch message.role {
            case .user:
                Spacer(minLength: 0)
                UserMessageBubble(message: $message, showMasked: showMasked)
                    .contextMenu { contextMenuItems }
            case .assistant:
                AssistantMessageBody(message: message, showMasked: showMasked)
                    .contextMenu { contextMenuItems }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        // No menu on the review screen, where a tap tags a word.
        if !message.isReviewing {
            if let onInspect, message.maskedText != nil, !showMasked {
                Button(action: onInspect) {
                    Label("What the AI saw", systemImage: "lock.shield")
                }
            }
            Button {
                UIPasteboard.general.string = showMasked ? (message.maskedText ?? message.text) : message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}

/// User message rendered word by word, so each word can be tagged on the review screen.
private struct UserMessageBubble: View {
    @Binding var message: Message
    let showMasked: Bool

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach($message.tokens) { $token in
                // Words folded into a multi-word placeholder have nothing to show.
                if !token.displayText(masked: showMasked).isEmpty {
                    InteractiveWordView(token: $token, showMasked: showMasked)
                }
            }
        }
        // Words can only be retagged before the message is sent.
        .allowsHitTesting(message.isReviewing)
        .padding(12)
        .background(Color(.darkGray))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: message.isReviewing ? .center : .trailing)
        .padding(message.isReviewing ? .horizontal : .leading, message.isReviewing ? 20 : 40)
    }
}

/// Assistant reply rendered as Markdown, with fenced code blocks.
private struct AssistantMessageBody: View {
    let message: Message
    let showMasked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message.isError ? "PrivacyAI" : "Assistant",
                  systemImage: message.isError ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(message.isError ? .orange : .secondary)

            let text = showMasked ? (message.maskedText ?? message.text) : message.text
            let segments = MarkdownSegment.parse(text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(segments.indices, id: \.self) { index in
                    switch segments[index] {
                    case .text(let markdown):
                        Text(Self.attributed(markdown))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    case .code(let code):
                        CodeBlockView(code: code)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func attributed(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}
