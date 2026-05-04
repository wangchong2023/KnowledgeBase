// AppRouter.swift
//
// 作者: Wang Chong
// 功能说明: 应用程序路由目标定义
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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
    
    /// 当前主 Tab
    var selectedTab: AppTab = .wiki
    
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

