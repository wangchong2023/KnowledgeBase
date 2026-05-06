// KMWindowSceneDelegate.swift
//
// 作者: Wang Chong
// 功能说明: 窗口场景代理，支持多窗口环境下的根视图初始化与环境注入
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级文档规范，支持多窗口环境
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 场景代理（多窗口支持）
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