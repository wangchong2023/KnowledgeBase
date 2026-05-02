import SwiftUI

/// 响应式侧边栏 (iPad/Mac 专属)
/// 将传统的底部 Tab 转换为更符合大屏习惯的垂直侧边栏。
struct AdaptiveSidebarView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    
    var body: some View {
        List {
            Section(Localized.tr("sidebar.knowledge")) {
                sidebarRow(for: .wiki)
                sidebarRow(for: .graph)
                sidebarRow(for: .search)
            }
            
            Section(Localized.tr("sidebar.tools")) {
                sidebarRow(for: .ingest)
                
                // 快捷跳转到任务中心 (作为 Wiki 模块的子操作)
                Button(action: {
                    selectedTab = .wiki
                    store.selectedTool = .taskCenter
                }) {
                    Label(Localized.tr("aitask.center.title"), systemImage: "bolt.horizontal.circle")
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
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .help(Localized.tr("security.lockVault"))
            }
        }
    }
    
    private func sidebarRow(for tab: ContentView.AppTab) -> some View {
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
    @Binding var selectedTab: ContentView.AppTab
    @Binding var languageForceUpdate: Bool
    var heroNamespace: Namespace.ID
    
    var body: some View {
        switch selectedTab {
        case .wiki:
            NavigationView(selectedTab: $selectedTab, heroNamespace: heroNamespace)
        case .graph:
            GraphContainerView(heroNamespace: heroNamespace)
        case .search:
            SearchView()
        case .ingest:
            IngestView()
        case .settings:
            SettingsView(languageForceUpdate: $languageForceUpdate)
        }
    }
}
