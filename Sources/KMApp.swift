// KMApp.swift
//
// 作者: Wang Chong
// 功能说明: 本文件是“知识灵动 (Knowledge Management)”应用程序的顶层入口点。
// 它负责协调整个应用的生命周期，并执行以下核心任务：
// 1. 基础设施注入：初始化 Logger, SQLiteStore, SecurityManager 等底层服务。
// 2. 依赖注入管理：利用 ServiceContainer 实现跨层级服务的解耦与注册。
// 3. 状态树初始化：构建 KMStore 及各类子 Store，驱动 SwiftUI 声明式 UI 的数据流。
// 4. 全局交互定义：配置窗口组、启动闪屏逻辑、全局主题管理及 macOS 原生快捷键命令。
// 版本: 1.2
// 修改记录:
//   - 2026-05-02: 初始架构创建。
//   - 2026-05-05: 升级全工程文档规范，规范化 DI 注入流程与生命周期注释。
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 应用程序主入口
/// 负责管理顶层状态树与全局服务生命周期
@main
@MainActor
struct KMApp: App {
    // ── 顶层状态持有者 ──
    @State private var store: KMStore
    @State private var ingestStore = IngestStore()
    @State private var router = AppRouter.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var llmService = LLMService()
    @State private var synthesisStore = SynthesisStore()
    @State private var hasSeenSplash = false
    
    /// 初始化应用环境
    /// 在此阶段完成 L0-L2 层的依赖注入与服务挂载
    init() {
        // 1. 初始化基础设施服务 (L0)
        // 这些服务不依赖于业务逻辑，提供底层存储、安全与观测能力
        let logger = Logger()
        let sqliteStore = SQLiteStore()
        let backupService = BackupService()
        let snapshotService = SnapshotService()
        let securityService = VaultStorageSecurityService()
        
        // 2. 注册协议与实例 (Service Locator 模式)
        // 确保后续各模块可以通过 @Inject 属性包装器安全访问这些单例
        ServiceContainer.shared.register(logger, for: (any LoggerProtocol).self)
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(backupService, for: BackupService.self)
        ServiceContainer.shared.register(snapshotService, for: SnapshotService.self)
        ServiceContainer.shared.register(securityService, for: VaultStorageSecurityService.self)
        
        // 3. 初始化领域服务 (L1)
        // 包含页面链接审计、网络摄取、健康检查等业务逻辑组件
        ServiceContainer.shared.register(LinkService(), for: LinkService.self)
        ServiceContainer.shared.register(IngestService(), for: IngestService.self)
        ServiceContainer.shared.register(LintService(), for: LintService.self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(DeepLinkService(), for: DeepLinkService.self)
        ServiceContainer.shared.register(PerformanceService(), for: PerformanceService.self)
        ServiceContainer.shared.register(AccessibilityService(), for: AccessibilityService.self)
        
        // 4. 初始化应用能力层 (L2)
        // 涉及 LLM 推理、知识合成等高阶 AI 能力
        let llm = LLMService.shared
        _llmService = StateObject(wrappedValue: llm)
        
        ServiceContainer.shared.register(llm, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(llm, for: LLMService.self)
        
        ServiceContainer.shared.register(KnowledgeInsightService(), for: KnowledgeInsightService.self)
        ServiceContainer.shared.register(PluginRegistry.shared, for: PluginRegistry.self)
        ServiceContainer.shared.register(WorkflowService.shared, for: WorkflowService.self)
        ServiceContainer.shared.register(AISynthesisService.shared, for: AISynthesisService.self)
        
        // 5. 在服务注册完成后初始化 Store
        // KMStore 依赖于上述所有注入的服务，故必须放在最后初始化
        _store = State(wrappedValue: KMStore())
        
        // 6. 配置全局 UI 样式
        #if canImport(UIKit)
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.wikiAccent)
        #endif
    }

    /// 应用主场景定义
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 主内容视图：注入所有必需的环境对象
                ContentView()
                    .environment(store)
                    .environment(store.aiWorkflowStore)
                    .environment(synthesisStore)
                    .environment(store.searchStore)
                    .environment(store.settingsStore)
                    .environment(ingestStore)
                    .environment(router)
                    .environmentObject(themeManager)
                    .environmentObject(llmService)
                    .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
                    .environment(\.wikiAccentColor, themeManager.accentColor)

                // 启动闪屏层：覆盖在主视图之上
                if !hasSeenSplash {
                    SplashView(onDismiss: {
                        if hasSeenSplash { return } // 防重触发
                        withAnimation(.easeInOut(duration: 0.6)) {
                            print("🔍 [NAV-DIAG] Splash dismissed. Posting notification.")
                            hasSeenSplash = true
                            // 通知系统闪屏已结束，可开始执行一些重型初始化任务
                            NotificationCenter.default.post(name: NSNotification.Name("splashDismissed"), object: nil)
                        }
                    })
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: hasSeenSplash)
        }
        // macOS / iPadOS 原生快捷键指令组
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(Localized.tr("creation.newPage")) {
                    NotificationCenter.default.post(name: .createNewPage, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}