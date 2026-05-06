// ViewFactory.swift
//
// 作者: Wang Chong
// 功能说明: 视图工厂：负责将抽象路由转换为真实视图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

/// 视图工厂：负责将抽象路由转换为真实视图
/// 它是解耦路由逻辑与 UI 实现的关键层
@MainActor
struct ViewFactory {
    @ViewBuilder
    static func makeView(for route: AppRoute) -> some View {
        switch route {
        case .dashboard:
            KnowledgeDashboardView()
        case .index(let type):
            IndexView(filterType: type)
        case .pageDetail(let id):
            PageDetailWrapper(id: id)
        case .tagCloud:
            TagCloudView()
        case .taskCenter:
            TaskCenterView()
        case .chat:
            ChatViewContent(selectedTab: .constant(.wiki)) // 临时兼容，后续可进一步优化
        case .synthesis:
            SynthesisViewWrapper()
        case .settings:
            SettingsViewWrapper()
        case .log:
            LogView()
        case .collab:
            CollaborationView()
        case .weeklyReport:
            WeeklyReportView()
        case .lint:
            LintWrapper()
        }
    }
}

// MARK: - 包装器 (用于处理复杂的 Binding 或依赖)

struct PageDetailWrapper: View {
    let id: UUID
    @Environment(KMStore.self) var store
    
    var body: some View {
        if let page = store.pages.first(where: { $0.id == id }) {
            PageDetailView(page: page)
        } else {
            ContentUnavailableView(Localized.tr("error.notFound"), systemImage: "doc.questionmark")
        }
    }
}

struct SynthesisViewWrapper: View {
    @Environment(AppRouter.self) var router
    var body: some View {
        SynthesisView(selection: Binding(
            get: { router.sidebarSelection },
            set: { router.sidebarSelection = $0 }
        ), selectedTab: Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        ))
    }
}

struct SettingsViewWrapper: View {
    // 假设 SettingsView 需要 onboardingService
    // 实际项目中可以从 Environment 或全局单例获取
    var body: some View {
        SettingsView(onboardingService: OnboardingService(), languageForceUpdate: .constant(false))
    }
}

struct LintWrapper: View {
    @Environment(AppRouter.self) var router
    var body: some View {
        LintView(selection: Binding(
            get: { router.sidebarSelection },
            set: { router.sidebarSelection = $0 }
        ))
    }
}
