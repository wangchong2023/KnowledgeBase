import SwiftUI

@main
struct KMApp: App {
    @StateObject private var store = KMStore()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var llmService = LLMService()
    @State private var hasSeenSplash = false
    
    var body: some Scene {
        WindowGroup {
            // ContentView 已在 body 内读取 themeManager.accentColorRaw 触发重建
            // KMApp 这里的 .tint 依赖 ContentView 的 environment 传递即可
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(themeManager)
                    .environmentObject(llmService)
                    .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
                
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
    }
}
