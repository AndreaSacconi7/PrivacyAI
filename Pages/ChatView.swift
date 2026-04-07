// ChatView.swift (o ContentView.swift)
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var chatStore = ChatStore()
    @FocusState private var isFocused: Bool
    
    // Stato per controllare il menu
    @State private var isSidebarOpened: Bool = false
    // 1. Stato per controllare l'apertura delle impostazioni
    @State private var isSettingsOpened: Bool = false
    
    var body: some View {
        // IL SEGRETO: ZStack è il genitore principale!
        ZStack {
            
            // --- LIVELLO 1: L'APP PRINCIPALE ---
            NavigationStack { // Sostituito NavigationView con NavigationStack (più moderno)
                VStack(spacing: 0) {
                    // Area dei messaggi a scorrimento
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach($viewModel.messages) { $message in
                                    MessageView(message: $message, onPrivacyTap: {
                                        // Passiamo direttamente i token normali (che ora contengono il segreto!)
                                        viewModel.privacyMessageToShow = message
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.isPrivacyOverlayOpened = true
                                            isFocused = false
                                        }
                                    })
                                    .id(message.id)
                                }
                                
                                // Indicatore di digitazione simulato
                                if viewModel.isTyping {
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
                        // Autoscroll E AUTO-SALVATAGGIO
                        .onChange(of: viewModel.messages.count) { _ in
                            scrollToBottom(proxy: proxy)
                            
                            // Auto-salvataggio silente stile ChatGPT
                            if !viewModel.messages.isEmpty {
                                // Salviamo la chat (se è nuova crea l'ID, se esiste la aggiorna)
                                let updatedId = chatStore.saveChat(
                                    messages: viewModel.messages,
                                    existingId: viewModel.currentSessionId
                                )
                                // Aggiorniamo l'ID nel ViewModel!
                                // Così dal secondo messaggio in poi, non sarà più nil.
                                viewModel.currentSessionId = updatedId
                            }
                        }
                    }
                    .onTapGesture {
                        isFocused = false // Chiude la tastiera
                    }
                    
                    // Barra di input fissa in basso
                    InputBarView(text: $viewModel.inputText, isFocused: $isFocused) {
                        Task {
                            await viewModel.prepareForReview()
                        }
                    }
                }
                .navigationTitle("PrivacyAI")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 1. Usare ToolbarItem (singolo) invece di ToolbarItemGroup
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSidebarOpened.toggle()
                                isFocused = false
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.primary)
                        }
                    }

                    // 2. Usare ToolbarItem (singolo) anche qui
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            chatStore.saveChat(messages: viewModel.messages, existingId: viewModel.currentSessionId)
                            viewModel.startNewChat()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.primary)
                        }
                    }
                }
                // Apre la pagina di revisione dal basso
                .sheet(isPresented: $viewModel.showReviewScreen) {
                    ReviewView(
                        pendingMessage: viewModel.pendingMessage,
                        onSend: { finalMessage in // Rinominato in finalMessage per chiarezza
                            viewModel.confirmAndSendMessage(reviewedMessage: finalMessage)
                        }
                    )
                }
            } // <-- FINE NAVIGATION STACK
            
            
            // --- LIVELLO 2: TENDA OSCURANTE ---
            if isSidebarOpened {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Toccando fuori dal menu, si chiude
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSidebarOpened = false
                        }
                    }
            }
            
            // --- LIVELLO 3: LA BARRA LATERALE ---
            HStack {
                // 2. Passiamo l'azione di apertura alla Sidebar
                SidebarView(isShowing: $isSidebarOpened,
                    store: chatStore,
                    onSettingsTap: {
                        withAnimation {
                            isSettingsOpened = true // Poi apriamo le impostazioni
                        }
                    },
                    onChatSelected: { selectedSession in // <-- LA MAGIA AVVIENE QUI
                                
                        // UX TRICK: Se l'utente sta scrivendo in una chat non salvata e clicca su una vecchia,
                        // salviamo la chat corrente prima di rimpiazzarla per non fargli perdere i dati!
                        if !viewModel.messages.isEmpty {
                            // 👇 L'ERRORE ERA QUI! Mancava "existingId: viewModel.currentSessionId"
                            chatStore.saveChat(messages: viewModel.messages, existingId: viewModel.currentSessionId)
                        }
                                
                        // 1. Diciamo al ViewModel di caricare la vecchia chat
                        viewModel.loadChat(session: selectedSession)
                                
                        // 2. Chiudiamo dolcemente la barra laterale
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSidebarOpened = false
                        }
                    }
                )
                .offset(x: isSidebarOpened ? 0 : -UIScreen.main.bounds.width)
                Spacer()
            }
            .ignoresSafeArea(edges: .bottom)
            
            if viewModel.isPrivacyOverlayOpened {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isPrivacyOverlayOpened = false
                        }
                    }
            }
            
            // Il pannello vero e proprio
            HStack {
                Spacer() // Spinge il pannello tutto a destra!
                
                PrivacyOverlayView(
                    message: viewModel.privacyMessageToShow,
                    isShowing: $viewModel.isPrivacyOverlayOpened
                )
                // Se è chiuso, lo nascondiamo FUORI dallo schermo a DESTRA (+ larghezza)
                .offset(x: viewModel.isPrivacyOverlayOpened ? 0 : UIScreen.main.bounds.width)
            }
            .ignoresSafeArea(edges: .bottom)
            
        } // <-- FINE ZSTACK
        // 3. Modificatore per mostrare l'overlay dal basso (sheet)
        .sheet(isPresented: $isSettingsOpened) {
            SettingsOverlay(onDismiss: {
                isSettingsOpened = false
            })
        }
        // Aggiungiamo il rilevatore di gesture a tutto lo schermo
        .gesture(
            DragGesture()
                .onEnded { value in
                    let horizontalSwipe = value.translation.width
                    let verticalSwipe = value.translation.height
                    
                    // Controlliamo che sia uno swipe orizzontale
                    if abs(horizontalSwipe) > abs(verticalSwipe) {
                        
                        // --- SWIPE VERSO DESTRA --->
                        if horizontalSwipe > 50 {
                            
                            // 1. IL CONTROLLO MAGICO
                            if viewModel.isPrivacyOverlayOpened {
                                // BONUS UX: Se il pannello privacy (a destra) è aperto,
                                // lo swipe verso destra lo chiude! (Molto naturale per l'utente)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.isPrivacyOverlayOpened = false
                                }
                            } else {
                                // 2. COMPORTAMENTO NORMALE
                                // Apre la barra laterale solo se il pannello privacy è chiuso
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSidebarOpened = true
                                    isFocused = false // Chiude la tastiera se aperta
                                }
                            }
                        }
                        
                        // <--- SWIPE VERSO SINISTRA ---
                        else if horizontalSwipe < -50 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSidebarOpened = false
                            }
                        }
                    }
                }
        ) // <-- FINE GESTURE
    }
    
    // Funzione di supporto per l'autoscroll
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if let lastMessageId = viewModel.messages.last?.id {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        }
    }
}

// Anteprima per Xcode
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
