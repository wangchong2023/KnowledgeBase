// KMApp.swift
//
// 作者: Wang Chong
// 功能说明: struct KMApp
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

@main
@MainActor
struct KMApp: App {
    @State private var store: KMStore
    @State private var ingestStore = IngestStore()
    @State private var router = AppRouter.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var llmService = LLMService()
    @State private var hasSeenSplash = false
    
    init() {
        // 1. 初始化基础设施服务 (L0)
        let logService = LogService()
        let sqliteStore = SQLiteStore()
        let backupService = BackupService()
        let snapshotService = SnapshotService()
        let securityService = VaultStorageSecurityService()
        
        // 2. 注册协议与实例 (Service Locator 模式)
        ServiceContainer.shared.register(logService, for: (any LogServiceProtocol).self)
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(backupService, for: BackupService.self)
        ServiceContainer.shared.register(snapshotService, for: SnapshotService.self)
        ServiceContainer.shared.register(securityService, for: VaultStorageSecurityService.self)
        
        // 3. 初始化领域服务 (L1)
        ServiceContainer.shared.register(LinkService(), for: LinkService.self)
        ServiceContainer.shared.register(IngestService(), for: IngestService.self)
        ServiceContainer.shared.register(LintService(), for: LintService.self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(DeepLinkService(), for: DeepLinkService.self)
        ServiceContainer.shared.register(PerformanceService(), for: PerformanceService.self)
        ServiceContainer.shared.register(AccessibilityService(), for: AccessibilityService.self)
        
        // 4. 初始化应用能力层 (L2)
        let mainLLM = LLMService()
        ServiceContainer.shared.register(mainLLM, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(mainLLM, for: LLMService.self)
        ServiceContainer.shared.register(KnowledgeInsightService(), for: KnowledgeInsightService.self)
        ServiceContainer.shared.register(PluginRegistry.shared, for: PluginRegistry.self)
        ServiceContainer.shared.register(WorkflowService.shared, for: WorkflowService.self)
        
        // 5. 在服务注册完成后初始化 Store (确保 @Inject 依赖已就绪)
        _store = State(wrappedValue: KMStore())
        
        // 6. 设置 UI 样式
        #if canImport(UIKit)
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.wikiAccent)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(store)
                    .environment(store.aiWorkflowStore)
                    .environment(SynthesisStore())
                    .environment(store.searchStore)
                    .environment(store.settingsStore)
                    .environment(ingestStore)
                    .environment(router)
                    .environmentObject(themeManager)
                    .environmentObject(llmService)
                    .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
                    .environment(\.wikiAccentColor, themeManager.accentColor)

                if !hasSeenSplash {
                    SplashView(onDismiss: {
                        if hasSeenSplash { return } // 防重触发
                        withAnimation(.easeInOut(duration: 0.6)) {
                            print("🔍 [NAV-DIAG] Splash dismissed. Posting notification.")
                            hasSeenSplash = true
                            NotificationCenter.default.post(name: NSNotification.Name("splashDismissed"), object: nil)
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