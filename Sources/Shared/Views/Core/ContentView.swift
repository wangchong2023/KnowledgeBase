import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var selectedTab: AppTab = .wiki
    @State private var showCreateSheet = false
    @State private var showCommandPalette = false
    @State private var languageForceUpdate: Bool = false
    @Namespace private var heroNamespace
    
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
    
    @StateObject private var onboardingService = OnboardingService()
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        let tintColor = ThemeManager.colorForName(themeManager.accentColorRaw)
        
        ZStack {
            Group {
                if horizontalSizeClass == .regular {
                    adaptiveSplitView(tintColor: tintColor)
                } else {
                    if #available(iOS 18, *) {
                        modernTabView(tintColor: tintColor)
                    } else {
                        legacyTabView(tintColor: tintColor)
                    }
                }
            }

            if store.securityService.isLocked {
                LockOverlayView()
                    .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            }
            
            OnboardingOverlay(service: onboardingService)
        }
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                onboardingService.nextStep()
            }
        }
    }
    
    // MARK: - iPad/Mac Adaptive SplitView
    @ViewBuilder
    private func adaptiveSplitView(tintColor: Color) -> some View {
        NavigationSplitView {
            AdaptiveSidebarView(selectedTab: $selectedTab)
        } detail: {
            AdaptiveDetailView(selectedTab: $selectedTab, languageForceUpdate: $languageForceUpdate, heroNamespace: heroNamespace)
        }
        .tint(tintColor)
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(400)])
                .presentationBackground(.clear)
        }
        .background {
            Button(Localized.tr("tab.search")) { showCommandPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
    }
    
    // MARK: - iOS 18+ Modern TabView (Bottom TabBar — consistent on iPhone & iPad)
    @available(iOS 18, *)
    @ViewBuilder
    private func modernTabView(tintColor: Color) -> some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.wiki.displayTitle, systemImage: AppTab.wiki.icon, value: AppTab.wiki) {
                wikiTabContent
            }

            Tab(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon, value: AppTab.graph) {
                graphTabContent
            }

            Tab(AppTab.search.displayTitle, systemImage: AppTab.search.icon, value: AppTab.search) {
                searchTabContent
            }

            Tab(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon, value: AppTab.ingest) {
                ingestTabContent
            }

            Tab(AppTab.settings.displayTitle, systemImage: AppTab.settings.icon, value: AppTab.settings) {
                SettingsView(languageForceUpdate: $languageForceUpdate)
            }
        }
        .tint(tintColor)
        .onOpenURL { url in
            if store.handleDeepLink(url) {
                store.consumeDeepLink()
            }
        }
        .sheet(isPresented: $store.showPerfDashboard) {
            PerformanceDashboardView(service: store.performanceService)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(400)])
                .presentationBackground(.clear)
        }
        .background {
            Button(Localized.tr("misc.action")) {
                showCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        }
    }
    
    // MARK: - iOS 17 Legacy TabView (Bottom TabBar)
    @ViewBuilder
    private func legacyTabView(tintColor: Color) -> some View {
        TabView(selection: $selectedTab) {
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
        .sheet(isPresented: $store.showPerfDashboard) {
            PerformanceDashboardView(service: store.performanceService)
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationDetents([.height(400)])
                .presentationBackground(.clear)
        }
        .background {
            Button(Localized.tr("misc.action")) {
                showCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        }
    }
    
    /// Wiki tab 内容，使用 @ViewBuilder 根据 languageForceUpdate 条件刷新
    /// 这样可以避免在 TabView 层级使用 .id() 导致 Menu 崩溃
    @ViewBuilder
    private var wikiTabContent: some View {
        if languageForceUpdate {
            NavigationView(selectedTab: $selectedTab, heroNamespace: heroNamespace)
                .id(languageForceUpdate)
        } else {
            NavigationView(selectedTab: $selectedTab, heroNamespace: heroNamespace)
        }
    }
    
    /// Graph tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var graphTabContent: some View {
        NavigationStack {
            if languageForceUpdate {
                GraphContainerView(heroNamespace: heroNamespace)
                    .id(languageForceUpdate)
            } else {
                GraphContainerView(heroNamespace: heroNamespace)
            }
        }
    }
    
    /// Search tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var searchTabContent: some View {
        NavigationStack {
            if languageForceUpdate {
                SearchView()
                    .id(languageForceUpdate)
            } else {
                SearchView()
            }
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
