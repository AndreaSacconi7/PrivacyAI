import SwiftUI

/// A single word chip. Tapping it opens a menu to tag it as personal information.
struct InteractiveWordView: View {
    @Binding var token: WordToken
    var showMasked = false

    var body: some View {
        Menu {
            ForEach(EntityCategory.allCases) { category in
                Button {
                    token.category = category
                } label: {
                    Label(category.displayName, systemImage: category.systemImage)
                }
            }
            if token.category != nil {
                Divider()
                Button("Remove tag", systemImage: "xmark", role: .destructive) {
                    token.category = nil
                }
            }
        } label: {
            Text(token.displayText(masked: showMasked))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(token.category?.color ?? .clear)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityLabel(token.category.map { "\(token.text), tagged as \($0.displayName)" } ?? token.text)
    }
}

extension EntityCategory {
    var color: Color {
        switch self {
        case .person: return .indigo
        case .location: return .teal
        case .organization: return .orange
        case .miscellaneous: return .purple
        }
    }
}
