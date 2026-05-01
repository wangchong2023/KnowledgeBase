import SwiftUI

@main
struct KMApp: App {
    @StateObject private var store = KMStore()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var llmService = LLMService()
    @State private var hasSeenSplash = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(themeManager)
                    .environmentObject(llmService)
                    .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
                    .environment(\.wikiAccentColor, themeManager.accentColor)

                if !hasSeenSplash {
                    SplashView(onDismiss: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            hasSeenSplash = true
                        }
                    })
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: hasSeenSplash)
        }
        // Register keyboard shortcuts for Mac Catalyst
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    NotificationCenter.default.post(name: .createNewPage, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}