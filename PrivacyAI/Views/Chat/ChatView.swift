import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    @State private var isSidebarOpen = false
    @State private var isSettingsOpen = false
    /// Message shown in the "what the LLM saw" panel.
    @State private var inspectedMessage: Message?

    private let panelAnimation = Animation.spring(response: 0.3, dampingFraction: 0.8)

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if viewModel.messages.isEmpty {
                        EmptyChatView()
                    } else {
                        messageList
                    }
                    InputBarView(
                        text: $viewModel.inputText,
                        isFocused: $isInputFocused,
                        isDisabled: viewModel.isWaitingForReply
                    ) {
                        Task { await viewModel.reviewInput() }
                    }
                }
                .navigationTitle("PrivacyAI")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $viewModel.pendingMessage) { message in
                    ReviewView(
                        message: message,
                        recognizerState: viewModel.recognizerState,
                        onSend: viewModel.send
                    )
                }
            }

            // Sidebar, sliding in from the left.
            dimmingLayer(isVisible: isSidebarOpen) { isSidebarOpen = false }
            HStack {
                SidebarView(
                    store: viewModel.store,
                    currentSessionID: viewModel.session.id,
                    onSelect: { session in
                        viewModel.open(session)
                        withAnimation(panelAnimation) { isSidebarOpen = false }
                    },
                    onDelete: viewModel.delete,
                    onSettingsTap: { isSettingsOpen = true }
                )
                .offset(x: isSidebarOpen ? 0 : -UIScreen.main.bounds.width)
                Spacer(minLength: 0)
            }

            // Privacy panel, sliding in from the right.
            dimmingLayer(isVisible: inspectedMessage != nil) { inspectedMessage = nil }
            HStack {
                Spacer(minLength: 0)
                PrivacyOverlayView(message: inspectedMessage) {
                    withAnimation(panelAnimation) { inspectedMessage = nil }
                }
                .offset(x: inspectedMessage == nil ? UIScreen.main.bounds.width : 0)
            }
        }
        .sheet(isPresented: $isSettingsOpen) {
            SettingsView(recognizerState: viewModel.recognizerState)
        }
        .gesture(panelSwipeGesture)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: .constant(message)) {
                            isInputFocused = false
                            withAnimation(panelAnimation) { inspectedMessage = message }
                        }
                        .id(message.id)
                    }

                    if viewModel.isWaitingForReply {
                        HStack {
                            ProgressView()
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .id("typingIndicator")
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
            }
            .onTapGesture { isInputFocused = false }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isInputFocused = false
                withAnimation(panelAnimation) { isSidebarOpen.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("Chat history")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: viewModel.startNewChat) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("New chat")
        }
    }

    @ViewBuilder
    private func dimmingLayer(isVisible: Bool, onTap: @escaping () -> Void) -> some View {
        if isVisible {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(panelAnimation) { onTap() } }
        }
    }

    /// Swipe right opens the sidebar (or closes the privacy panel);
    /// swipe left closes the sidebar.
    private var panelSwipeGesture: some Gesture {
        DragGesture().onEnded { value in
            let horizontal = value.translation.width
            guard abs(horizontal) > abs(value.translation.height), abs(horizontal) > 50 else { return }

            withAnimation(panelAnimation) {
                if horizontal > 0 {
                    if inspectedMessage != nil {
                        inspectedMessage = nil
                    } else {
                        isInputFocused = false
                        isSidebarOpen = true
                    }
                } else {
                    isSidebarOpen = false
                }
            }
        }
    }
}

private struct EmptyChatView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Chat privately")
                .font(.title3.weight(.semibold))
            Text("Names, places and organizations are detected on your device and replaced with placeholders before your message is sent to the AI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChatView()
}
