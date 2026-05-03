import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(KMStore.self) var store
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var selectedTab: AppTab = .wiki
    @State private var showCommandPalette = false
    @State private var languageForceUpdate: Bool = false
    @Namespace private var heroNamespace
    @StateObject private var medalService = MedalService.shared
    @State private var searchPath = NavigationPath()
    @State private var graphPath = NavigationPath()
    @State private var sidebarSelection: SidebarSelection? = nil
    
    enum AppTab: String, CaseIterable {
        case wiki
        case ingest
        case search
        case graph
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
        @Bindable var store = store
        let tintColor = ThemeManager.colorForName(themeManager.accentColorRaw)
        
        ZStack {
            Group {
                if horizontalSizeClass == .regular {
                    adaptiveSplitView(tintColor: tintColor)
                } else {
                    if #available(iOS 18.0, macOS 15.0, macCatalyst 18.0, *) {
                        modernTabView(tintColor: tintColor)
                    } else {
                        legacyTabView(tintColor: tintColor)
                    }
                }
            }
            .sheet(isPresented: $store.showCreateSheet) {
                CreatePageView()
            }

            if store.securityService.isLocked {
                LockOverlayView()
                    .transition(AnyTransition.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
            }
            
            OnboardingOverlay(service: onboardingService)
            
            // 全局奖章奖励弹窗
            if let medal = medalService.newlyEarnedMedal {
                MedalRewardPopup(medal: medal) {
                    withAnimation(.spring()) {
                        medalService.newlyEarnedMedal = nil
                    }
                }
                .zIndex(200)
                .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
            }
            
            // 功能引导弹窗 (Coach Marks)
            if let coachMark = store.pendingCoachMark {
                CoachMarkOverlay(type: coachMark, selectedTab: $selectedTab) {
                    store.pendingCoachMark = nil
                }
                .zIndex(300)
            }
        }
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                onboardingService.nextStep()
            }
        }
        .onChange(of: onboardingService.hasCompletedOnboarding) { _, newValue in
            if !newValue && onboardingService.currentStep == nil {
                onboardingService.nextStep()
            }
        }
        .wikiToast()
    }
    
    // MARK: - iPad/Mac Adaptive SplitView
    @ViewBuilder
    private func adaptiveSplitView(tintColor: Color) -> some View {
        NavigationSplitView {
            AdaptiveSidebarView(selectedTab: $selectedTab)
        } content: {
            // 中间列：根据 Tab 显示不同的二级列表
            switch selectedTab {
            case .wiki:
                SidebarView(heroNamespace: heroNamespace, selection: $sidebarSelection)
            default:
                Color.wikiBackground // 其他模块暂不显示二级列，或者显示空白
            }
        } detail: {
            // 详情列：显示主要内容
            AdaptiveDetailView(selectedTab: $selectedTab, selection: $sidebarSelection, languageForceUpdate: $languageForceUpdate, onboardingService: onboardingService, heroNamespace: heroNamespace)
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
    @available(iOS 18.0, macOS 15.0, macCatalyst 18.0, *)
    @ViewBuilder
    private func modernTabView(tintColor: Color) -> some View {
        @Bindable var store = store
        TabView(selection: $selectedTab) {
            Tab(AppTab.wiki.displayTitle, systemImage: AppTab.wiki.icon, value: AppTab.wiki) {
                wikiTabContent
            }

            Tab(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon, value: AppTab.ingest) {
                ingestTabContent
            }

            Tab(AppTab.search.displayTitle, systemImage: AppTab.search.icon, value: AppTab.search) {
                searchTabContent
            }

            Tab(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon, value: AppTab.graph) {
                graphTabContent
            }

            Tab(AppTab.settings.displayTitle, systemImage: AppTab.settings.icon, value: AppTab.settings) {
                SettingsView(onboardingService: onboardingService, languageForceUpdate: $languageForceUpdate)
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
        @Bindable var store = store
        TabView(selection: $selectedTab) {
            wikiTabContent
                .accessibilityIdentifier("Wiki")
                .tabItem {
                    Label(AppTab.wiki.displayTitle, systemImage: AppTab.wiki.icon)
                }
                .tag(AppTab.wiki)

            ingestTabContent
                .accessibilityIdentifier("Ingest")
                .tabItem {
                    Label(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon)
                }
                .tag(AppTab.ingest)

            searchTabContent
                .accessibilityIdentifier("Search")
                .tabItem {
                    Label(AppTab.search.displayTitle, systemImage: AppTab.search.icon)
                }
                .tag(AppTab.search)

            graphTabContent
                .accessibilityIdentifier("Graph")
                .tabItem {
                    Label(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon)
                }
                .tag(AppTab.graph)

            SettingsView(onboardingService: onboardingService, languageForceUpdate: $languageForceUpdate)
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
        NavigationStack(path: $graphPath) {
            Group {
                if languageForceUpdate {
                    GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                        .id(languageForceUpdate)
                } else {
                    GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                }
            }
            .navigationDestination(for: WikiPage.self) { page in
                PageDetailView(page: page)
                    .environment(\.navigate, NavigateAction { target in
                        Task { @MainActor in
                            graphPath.append(target)
                        }
                    })
            }
            .environment(\.navigate, NavigateAction { target in
                Task { @MainActor in
                    graphPath.append(target)
                }
            })
        }
    }
    
    /// Search tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var searchTabContent: some View {
        NavigationStack(path: $searchPath) {
            SearchView()
                .id(languageForceUpdate)
                .navigationDestination(for: WikiPage.self) { page in
                    PageDetailView(page: page)
                        .environment(\.navigate, NavigateAction { target in
                            Task { @MainActor in
                                searchPath.append(target)
                            }
                        })
                }
                .environment(\.navigate, NavigateAction { target in
                    Task { @MainActor in
                        searchPath.append(target)
                    }
                })
        }
    }

    /// Ingest tab 内容，languageForceUpdate 时强制刷新
    @ViewBuilder
    private var ingestTabContent: some View {
        if languageForceUpdate {
            IngestView(selectedTab: $selectedTab)
                .id(languageForceUpdate)
        } else {
            IngestView(selectedTab: $selectedTab)
        }
    }
}

#Preview {
    ContentView()
        .environment(KMStore())
        .environmentObject(ThemeManager())
        .environmentObject(LLMService())
}

// MARK: - Coach Mark Overlay
struct CoachMarkOverlay: View {
    let type: KMStore.CoachMarkType
    @Binding var selectedTab: ContentView.AppTab
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }
            
            VStack(spacing: 24) {
                // 图标
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.wikiAccent, .wikiSource], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: .wikiAccent.opacity(0.3), radius: 10, y: 5)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                
                VStack(spacing: 12) {
                    Text(Localized.tr(titleKey))
                        .font(.title3.bold())
                        .foregroundStyle(.wikiText)
                    
                    Text(Localized.tr(descKey))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1 : 0)
                
                Button(action: performAction) {
                    Text(Localized.tr(actionKey))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.wikiAccent)
                        )
                }
                .scaleEffect(isAnimating ? 1 : 0.9)
                .opacity(isAnimating ? 1 : 0)
                
                Button(action: dismissWithAnimation) {
                    Text(Localized.tr("misc.skip"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.top, 4)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.wikiCard)
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
            )
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    private var iconName: String {
        switch type {
        case .graphDiscovery: return "circle.hexagongrid.fill"
        }
    }
    
    private var titleKey: String {
        switch type {
        case .graphDiscovery: return "coachmark.graphDiscovery.title"
        }
    }
    
    private var descKey: String {
        switch type {
        case .graphDiscovery: return "coachmark.graphDiscovery.desc"
        }
    }
    
    private var actionKey: String {
        switch type {
        case .graphDiscovery: return "coachmark.graphDiscovery.action"
        }
    }
    
    private func performAction() {
        HapticManager.shared.trigger(.success)
        switch type {
        case .graphDiscovery:
            UserDefaults.standard.set(true, forKey: "hasShownGraphCoachMark")
            withAnimation {
                selectedTab = .graph
            }
        }
        dismissWithAnimation()
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}
