import SwiftUI

@main
struct PrivacyAIApp: App {
    init() {
        LLMSettings.migrateLegacySettings()
    }

    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}
