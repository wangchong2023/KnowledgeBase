// NavigationView.swift
//
// 作者: Wang Chong
// 功能说明: struct NavigationView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

@preconcurrency import SwiftUI
import WebKit

@MainActor
struct NavigationView: View {
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    @Binding var selectedTab: AppTab
    var heroNamespace: Namespace.ID
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var renderNonce = UUID() // 强制重绘标记 (Platinum Experience Item #5)
    
    var body: some View {
        @Bindable var router = router
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace, selection: $router.sidebarSelection)
        } detail: {
            NavigationStack(path: $router.path) {
                DetailContentView(selection: $router.sidebarSelection, selectedTab: $selectedTab)
                    .id("\(String(describing: router.sidebarSelection))-\(renderNonce.uuidString)")
                    .navigationDestination(for: AppRoute.self) { route in
                        ViewFactory.makeView(for: route)
                    }
                    .navigationDestination(for: WikiPage.self) { page in
                        PageDetailView(page: page)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("splashDismissed"))) { _ in
            router.path = NavigationPath()
            renderNonce = UUID()
        }
    }
}

// MARK: - Detail Content Wrapper
struct DetailContentView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: AppTab
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    
    var body: some View {
        @Bindable var router = router

        destinationView(for: selection)
    }

    /// 根据 SidebarSelection 路由到对应视图
    @ViewBuilder
    private func destinationView(for selection: SidebarSelection?) -> some View {
        if let selection = selection {
            ViewFactory.makeView(for: selection.asRoute())
        } else {
            wikiLandingView
        }
    }

    private var wikiLandingView: some View {
        ContentUnavailableView(
            Localized.tr("sidebar.title"),
            systemImage: "books.vertical.fill",
            description: Text(Localized.tr("sidebar.allPages"))
        )
    }
}
