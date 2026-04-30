import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var selectedTab: AppTab = .wiki
    @State private var showCreateSheet = false
    @State private var showPerfDashboard = false
    @State private var languageForceUpdate: Bool = false
    
    enum AppTab: String, CaseIterable {
        case wiki
        case graph
        case search
        case ingest
        case settings
        
        var displayTitle: String {
            switch self {
            case .wiki: return Localized.tr("tab.wiki")
            case .graph: return Localized.tr("tab.graph")
            case .search: return Localized.tr("tab.search")
            case .ingest: return Localized.tr("tab.ingest")
            case .settings: return Localized.tr("tab.settings")
            }
        }
        
        var icon: String {
            switch self {
            case .wiki: return "books.vertical.fill"
            case .graph: return "circle.hexagongrid.fill"
            case .search: return "magnifyingglass"
            case .ingest: return "tray.and.arrow.down.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        // ⚠️ 必须在 body 内直接读 accentColorRaw，才能让 SwiftUI 追踪依赖
        // 不能放到计算属性里，否则 SwiftUI diff 不会感知变化
        let tintColor = ThemeManager.colorForName(themeManager.accentColorRaw)
        
        return TabView(selection: $selectedTab) {
            wikiTabContent
                .accessibilityIdentifier("Wiki")
                .tabItem {
                    Label(AppTab.wiki.displayTitle, systemImage: AppTab.wiki.icon)
                }
                .tag(AppTab.wiki)

            graphTabContent
                .accessibilityIdentifier("Graph")
                .tabItem {
                    Label(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon)
                }
                .tag(AppTab.graph)

            searchTabContent
                .accessibilityIdentifier("Search")
                .tabItem {
                    Label(AppTab.search.displayTitle, systemImage: AppTab.search.icon)
                }
                .tag(AppTab.search)

            ingestTabContent
                .accessibilityIdentifier("Ingest")
                .tabItem {
                    Label(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon)
                }
                .tag(AppTab.ingest)

            SettingsView(languageForceUpdate: $languageForceUpdate)
                .accessibilityIdentifier("Settings")
                .tabItem {
                    Label(AppTab.settings.displayTitle, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(tintColor)
        .onOpenURL { url in
            if store.handleDeepLink(url) {
                store.consumeDeepLink()
            }
        }
        .sheet(isPresented: $showPerfDashboard) {
            PerformanceDashboardView(service: store.performanceService)
        }
    }
    
    /// Wiki tab 内容，使用 @ViewBuilder 根据 languageForceUpdate 条件刷新
    /// 这样可以避免在 TabView 层级使用 .id() 导致 Menu 崩溃
    @ViewBuilder
    private var wikiTabContent: some View {
        if languageForceUpdate {
            WikiNavigationView(selectedTab: $selectedTab)
                .id(languageForceUpdate)
        } else {
            WikiNavigationView(selectedTab: $selectedTab)
        }
    }
    
    /// Graph tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var graphTabContent: some View {
        if languageForceUpdate {
            GraphContainerView()
                .id(languageForceUpdate)
        } else {
            GraphContainerView()
        }
    }
    
    /// Search tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var searchTabContent: some View {
        if languageForceUpdate {
            SearchView()
                .id(languageForceUpdate)
        } else {
            SearchView()
        }
    }

    /// Ingest tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var ingestTabContent: some View {
        if languageForceUpdate {
            IngestView()
                .id(languageForceUpdate)
        } else {
            IngestView()
        }
    }
}
