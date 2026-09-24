import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: ChatStore
    let currentSessionID: ChatSession.ID
    let onSelect: (ChatSession) -> Void
    let onDelete: (ChatSession) -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.title2.weight(.bold))
                Spacer()
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if store.sessions.isEmpty {
                Text("No saved chats yet.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(store.sessions) { session in
                        Button { onSelect(session) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Text(session.updatedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(session.id == currentSessionID ? Color(.systemGray5) : Color.clear)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(session) }
                        }
                    }
                }
                .listStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .frame(width: UIScreen.main.bounds.width)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
