// AppRouter.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的全局路由管理器（AppRouter），作为应用导航逻辑的核心大脑。
// 该类基于 SwiftUI 的现代导航堆栈（NavigationPath）与观察者模式，提供了卓越的视图切换能力：
// 1. 声明式路径管理：通过集中化的 AppRoute 枚举解耦了视图间的直接依赖，支持动态推栈、平级切换及“回到根路径”的操作。
// 2. 状态机同步逻辑：智能维护侧边栏选中项（SidebarSelection）与主标签（AppTab）的一致性，确保在跨平台（iPadOS vs iOS）布局切换时导航状态的透明迁移。
// 3. 空间历史追踪：内置了轻量级的导航历史（Breadcrumbs）记录机制，为用户提供最近访问页面的快速回溯能力。
// 4. 外部调度接入：提供单例接口支持 Deep Link、搜索跳转及系统级指令对应用路由的直接编排。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，完善导航状态管理与历史追踪逻辑说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import Observation

/// 应用程序路由目标定义
/// 使用枚举解耦视图的直接调用
enum AppRoute: Hashable, Identifiable {
    case dashboard
    case index(filterType: PageType? = nil)
    case pageDetail(id: UUID)
    case tagCloud
    case taskCenter
    case chat
    case synthesis
    case settings
    case log
    case collab
    case weeklyReport
    case lint
    
    var id: String {
        switch self {
        case .dashboard: return "dashboard"
        case .index(let type): return "index-\(type?.rawValue ?? "all")"
        case .pageDetail(let id): return "page-\(id.uuidString)"
        case .tagCloud: return "tagCloud"
        case .taskCenter: return "taskCenter"
        case .chat: return "chat"
        case .synthesis: return "synthesis"
        case .settings: return "settings"
        case .log: return "log"
        case .collab: return "collab"
        case .weeklyReport: return "weeklyReport"
        case .lint: return "lint"
        }
    }
}

/// 应用程序路由管理器
/// 集中管理导航状态，支持解耦跳转与状态持久化
@Observable
@MainActor
final class AppRouter {
    /// 全局单例，方便非视图层级调用（如 DeepLink 处理）
    static let shared = AppRouter()
    
    /// 核心导航路径
    var path = NavigationPath()
    
    /// 当前侧边栏选中项
    var sidebarSelection: SidebarSelection? = nil
    
    /// 当前主 Tab (通过 UserDefaults 持久化，防止后台切换后状态丢失)
    var selectedTab: AppTab {
        get {
            let raw = UserDefaults.standard.string(forKey: "app_selected_tab") ?? AppTab.wiki.rawValue
            return AppTab(rawValue: raw) ?? .wiki
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "app_selected_tab")
        }
    }
    
    /// 空间导航历史 (面包屑)
    var navigationHistory: [WikiPage] = []
    
    private init() {}
    
    // MARK: - 导航指令
    
    /// 添加到导航历史 (去重并限制长度)
    func addToHistory(_ page: WikiPage) {
        // 如果当前已经在历史末尾，则不重复添加
        if navigationHistory.last?.id == page.id { return }
        
        // 限制历史长度为 5 个 (UX 建议：过多会导致认知负担)
        if navigationHistory.count >= 5 {
            navigationHistory.removeFirst()
        }
        navigationHistory.append(page)
    }
    
    /// 清空导航历史
    func clearHistory() {
        navigationHistory.removeAll()
    }
    
    /// 跳转到指定目标
    func navigate(to route: AppRoute) {
        // 如果是详情跳转，则推入路径堆栈；否则作为顶层导航
        if isDetailRoute(route) {
            path.append(route)
        } else {
            // 顶层导航切换
            updateSelection(for: route)
            // 切换顶层时通常清空路径
            path = NavigationPath()
        }
    }
    
    /// 便捷跳转：指定页面
    func navigateToPage(id: UUID) {
        navigate(to: .pageDetail(id: id))
    }
    
    /// 便捷跳转：指定工具
    func navigateToTool(_ tool: KMStore.ToolItem) {
        sidebarSelection = .tool(tool)
        path = NavigationPath()
    }
    
    /// 返回上一级
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    /// 回到根视图
    func popToRoot() {
        path = NavigationPath()
    }
    
    // MARK: - 辅助逻辑
    
    private func isDetailRoute(_ route: AppRoute) -> Bool {
        switch route {
        case .pageDetail: return true
        default: return false
        }
    }
    
    private func updateSelection(for route: AppRoute) {
        switch route {
        case .dashboard: sidebarSelection = .tool(.dashboard)
        case .index(let type): sidebarSelection = type == nil ? .tool(.index) : .filteredIndex(type!)
        case .tagCloud: sidebarSelection = .tool(.tagCloud)
        case .taskCenter: sidebarSelection = .tool(.taskCenter)
        case .chat: sidebarSelection = .tool(.chat)
        case .synthesis: sidebarSelection = .tool(.synthesis)
        case .settings: selectedTab = .settings
        case .log: sidebarSelection = .tool(.log)
        case .collab: sidebarSelection = .tool(.collab)
        case .weeklyReport: sidebarSelection = .tool(.weeklyReport)
        case .lint: sidebarSelection = .tool(.lint)
        case .pageDetail(let id): sidebarSelection = .page(id)
        }
    }
}

