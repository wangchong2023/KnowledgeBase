// AdaptiveSidebarView.swift
//
// 作者: Wang Chong
// 功能说明: 响应式侧边栏 (iPad/Mac 专属)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 响应式侧边栏 (iPad/Mac 专属)
/// 将传统的底部 Tab 转换为更符合大屏习惯的垂直侧边栏。
struct AdaptiveSidebarView: View {
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    @Binding var selectedTab: AppTab
    
    var body: some View {
        List {
            Section(Localized.tr("sidebar.knowledge")) {
                sidebarRow(for: .wiki)
            }
            
            Section(Localized.tr("sidebar.tools")) {
                sidebarRow(for: .ingest)
                sidebarRow(for: .search)
                sidebarRow(for: .graph)
                
                // 快捷跳转到任务中心 (作为 Wiki 模块的子操作)
                Button(action: {
                    selectedTab = .wiki
                    router.navigateToTool(.taskCenter)
                }) {
                    Label(L10n.AI.Task.centerTitle, systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            Section(Localized.tr("sidebar.system")) {
                sidebarRow(for: .settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(Localized.tr("app.name"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    HapticManager.shared.trigger(.selection)
                    store.securityService.lock()
                }) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .help(Localized.tr("security.lockVault"))
            }
        }
    }
    
    private func sidebarRow(for tab: AppTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Label(tab.displayTitle, systemImage: tab.icon)
                .foregroundStyle(selectedTab == tab ? Color.wikiAccent : .primary)
        }
        .tag(tab)
    }
}

/// 响应式主内容区域
struct AdaptiveDetailView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: AppTab
    @Binding var selection: SidebarSelection?
    @Binding var languageForceUpdate: Bool
    @ObservedObject var onboardingService: OnboardingService
    var heroNamespace: Namespace.ID
    
    var body: some View {
        switch selectedTab {
        case .wiki:
            DetailContentView(selection: $selection, selectedTab: $selectedTab)
        case .graph:
            NavigationStack {
                GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                    .navigationDestination(for: WikiPage.self) { page in
                        PageDetailView(page: page)
                    }
            }
        case .search:
            NavigationStack {
                SearchView()
                    .navigationDestination(for: WikiPage.self) { page in
                        PageDetailView(page: page)
                    }
            }
        case .ingest:
            IngestView(selectedTab: $selectedTab)
        case .settings:
            SettingsView(onboardingService: onboardingService, languageForceUpdate: $languageForceUpdate)
        }
    }
}
