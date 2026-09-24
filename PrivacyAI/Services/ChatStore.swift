import Foundation
import OSLog

/// Persists chat sessions as a JSON file on the device.
@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []

    private let fileURL: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PrivacyAI", category: "ChatStore")

    init(fileURL: URL = ChatStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    /// Inserts or updates a session and moves it to the top of the history.
    func upsert(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
        save()
    }

    func delete(id: ChatSession.ID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    func session(withID id: ChatSession.ID) -> ChatSession? {
        sessions.first { $0.id == id }
    }

    // MARK: - Disk

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "chat_history.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            logger.error("Failed to load chat history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(sessions)
            // The history contains the original, unmasked text: keep it
            // encrypted while the device is locked.
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            logger.error("Failed to save chat history: \(error.localizedDescription)")
        }
    }
}
