import SwiftUI

// MARK: - Scene Delegate for Multi-Window Support
@available(iOS 16.0, macCatalyst 16.0, *)
class KMWindowSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let store = KMStore()
        let themeManager = ThemeManager()
        let llmService = LLMService()

        let contentView = ContentView()
            .environmentObject(store)
            .environmentObject(themeManager)
            .environmentObject(llmService)
            .environment(\.wikiAccentColor, themeManager.accentColor)

        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}