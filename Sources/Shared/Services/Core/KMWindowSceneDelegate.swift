// KMWindowSceneDelegate.swift
//
// 作者: Wang Chong
// 功能说明: class KMWindowSceneDelegate
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Scene Delegate for Multi-Window Support
@available(iOS 16.0, macCatalyst 16.0, *)
class KMWindowSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let themeManager = ThemeManager()
        let store: KMStore = ServiceContainer.shared.resolve(KMStore.self)
        let llmService: LLMService = ServiceContainer.shared.resolve(LLMService.self)

        let contentView = ContentView()
            .environment(store)
            .environmentObject(themeManager)
            .environmentObject(llmService)
            .environment(\.wikiAccentColor, themeManager.accentColor)

        window.rootViewController = UIHostingController(rootView: AnyView(contentView))
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}