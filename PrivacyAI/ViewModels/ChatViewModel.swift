import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    enum RecognizerState: Equatable {
        case loading
        case ready
        case unavailable(reason: String)
    }

    @Published private(set) var session = ChatSession()
    @Published var inputText = ""
    /// The message currently on the review screen, if any.
    @Published var pendingMessage: Message?
    @Published private(set) var isWaitingForReply = false
    @Published private(set) var recognizerState: RecognizerState = .loading

    let store: ChatStore
    private let recognizerTask: Task<Result<EntityRecognizer, Error>, Never>

    var messages: [Message] { session.messages }

    init(store: ChatStore? = nil) {
        self.store = store ?? ChatStore()
        // Loading the model takes a moment: start right away, off the main thread.
        recognizerTask = Task.detached(priority: .userInitiated) {
            do {
                return .success(try await EntityRecognizer.loadFromBundle())
            } catch {
                return .failure(error)
            }
        }
        Task { _ = await recognizer() }
    }

    // MARK: - Sending

    /// Runs on-device NER on the typed text and opens the review screen.
    func reviewInput() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWaitingForReply else { return }

        var message = Message(role: .user, text: text)
        message.isReviewing = true

        if let recognizer = await recognizer() {
            let entities = await Task.detached(priority: .userInitiated) {
                (try? recognizer.recognize(in: text)) ?? []
            }.value
            message.tokens = EntityRecognizer.tag(message.tokens, with: entities)
        }

        // Words masked earlier in this chat stay masked even if the model misses them now.
        for index in message.tokens.indices where message.tokens[index].category == nil {
            message.tokens[index].category = session.pseudonymizer.knownCategory(for: message.tokens[index].text)
        }

        pendingMessage = message
    }

    /// Masks the reviewed message, adds it to the chat and asks the LLM for a reply.
    func send(_ reviewedMessage: Message) {
        var message = reviewedMessage
        let masked = session.pseudonymizer.mask(message.tokens)
        message.tokens = masked.tokens
        message.maskedText = masked.maskedText
        message.isReviewing = false

        inputText = ""
        pendingMessage = nil
        append(message, toSessionWithID: session.id)

        Task { await requestReply() }
    }

    private func requestReply() async {
        let sessionID = session.id
        let pseudonymizer = session.pseudonymizer

        let client: LLMClient
        do {
            client = try LLMSettings.makeClient()
        } catch {
            append(.init(role: .assistant, text: error.localizedDescription, isError: true), toSessionWithID: sessionID)
            return
        }

        // Only masked text is ever sent: `maskedText` is nil for anything that
        // did not go through the pseudonymizer.
        let conversation = session.messages
            .filter { !$0.isError }
            .compactMap { message in message.maskedText.map { LLMChatMessage(role: message.role, content: $0) } }

        isWaitingForReply = true
        defer { isWaitingForReply = false }

        do {
            let maskedReply = try await client.complete(conversation)
            let reply = Message(role: .assistant, text: pseudonymizer.restore(maskedReply), maskedText: maskedReply)
            append(reply, toSessionWithID: sessionID)
        } catch {
            append(.init(role: .assistant, text: error.localizedDescription, isError: true), toSessionWithID: sessionID)
        }
    }

    // MARK: - Chat history

    func startNewChat() {
        session = ChatSession()
        inputText = ""
    }

    func open(_ session: ChatSession) {
        self.session = session
        inputText = ""
    }

    func delete(_ session: ChatSession) {
        store.delete(id: session.id)
        if session.id == self.session.id {
            startNewChat()
        }
    }

    // MARK: - Helpers

    /// Appends to the open chat, or to the stored one if the user switched
    /// chats while waiting for the reply.
    private func append(_ message: Message, toSessionWithID sessionID: ChatSession.ID) {
        if session.id == sessionID {
            session.messages.append(message)
            persist(session)
        } else if var storedSession = store.session(withID: sessionID) {
            storedSession.messages.append(message)
            persist(storedSession)
        }
    }

    private func persist(_ session: ChatSession) {
        var session = session
        session.updatedAt = Date()
        session.refreshTitle()
        if session.id == self.session.id {
            self.session = session
        }
        store.upsert(session)
    }

    private func recognizer() async -> EntityRecognizer? {
        switch await recognizerTask.value {
        case .success(let recognizer):
            recognizerState = .ready
            return recognizer
        case .failure(let error):
            recognizerState = .unavailable(reason: error.localizedDescription)
            return nil
        }
    }
}
