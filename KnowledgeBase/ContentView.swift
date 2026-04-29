import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var selectedTab: AppTab = .wiki
    @State private var showCreateSheet = false
    @State private var showPerfDashboard = false
    
    enum AppTab: String, CaseIterable {
        case wiki
        case graph
        case search
        case ingest
        case settings
        
        var displayTitle: String {
            switch self {
            case .wiki: return L.tr("tab.wiki")
            case .graph: return L.tr("tab.graph")
            case .search: return L.tr("tab.search")
            case .ingest: return L.tr("tab.ingest")
            case .settings: return L.tr("tab.settings")
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
            WikiNavigationView(selectedTab: $selectedTab)
                .accessibilityIdentifier("Wiki")
                .tabItem {
                    Label(AppTab.wiki.displayTitle, systemImage: AppTab.wiki.icon)
                }
                .tag(AppTab.wiki)

            GraphContainerView()
                .accessibilityIdentifier("Graph")
                .tabItem {
                    Label(AppTab.graph.displayTitle, systemImage: AppTab.graph.icon)
                }
                .tag(AppTab.graph)

            SearchView()
                .accessibilityIdentifier("Search")
                .tabItem {
                    Label(AppTab.search.displayTitle, systemImage: AppTab.search.icon)
                }
                .tag(AppTab.search)

            IngestView()
                .accessibilityIdentifier("Ingest")
                .tabItem {
                    Label(AppTab.ingest.displayTitle, systemImage: AppTab.ingest.icon)
                }
                .tag(AppTab.ingest)

            SettingsView()
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
}

// MARK: - Wiki Navigation (Main Wiki Browser)
struct WikiNavigationView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            ZStack {
                if let pageID = store.selectedPageID,
                   let page = store.pageByID(pageID) {
                    PageDetailView(page: page)
                } else {
                    WikiWelcomeView(selectedTab: $selectedTab)
                }

                // 引导 Tooltip 浮层（首次使用引导）
                if tooltipManager.activeTooltip == .createPage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                WikiTooltip(
                                    title: L.tr(tooltipManager.activeTooltip?.titleKey ?? ""),
                                    description: L.tr(tooltipManager.activeTooltip?.descriptionKey ?? ""),
                                    icon: tooltipManager.activeTooltip?.icon ?? "questionmark",
                                    arrowDirection: .bottom,
                                    accentColor: .wikiAccent
                                )
                                Button(action: {
                                    withAnimation { tooltipManager.activeTooltip = nil }
                                }) {
                                    Text(L.tr("misc.gotIt"))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.wikiSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.wikiCard)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 100)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: tooltipManager.activeTooltip)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        store.undo()
                    } label: {
                        Label(L.tr("undo.undo"), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!store.undoService.canUndo)

                    Button {
                        store.redo()
                    } label: {
                        Label(L.tr("undo.redo"), systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!store.undoService.canRedo)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!store.undoService.canUndo && !store.undoService.canRedo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showCreateSheet = true
                    // 显示创建引导 Tooltip
                    if !tooltipManager.isShown(.createPage) {
                        withAnimation { tooltipManager.activeTooltip = .createPage }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePageView()
        }
    }
}

// MARK: - Welcome View
struct WikiWelcomeView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @State private var showCreateSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero — 带点阵背景 + 光晕
                VStack(spacing: 16) {
                    ZStack {
                        // 点阵背景
                        WikiDotPattern(dotColor: .wikiBorder, spacing: 18, dotSize: 2)
                            .frame(width: 200, height: 100)
                            .opacity(0.5)

                        // 背景光晕
                        Circle()
                            .fill(Color.wikiAccent.opacity(0.08))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        // 主图标 + 发光
                        Image(systemName: "books.vertical.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.wikiAccent, .wikiConcept],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .wikiAccent.opacity(0.4), radius: 16, x: 0, y: 8)
                    }
                    .frame(height: 100)

                    Text("知识库")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.wikiText)

                    Text(L.tr("welcome.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 20) {
                    StatCard(title: L.tr("stat.totalPages"), value: "\(store.totalPages)", icon: "doc.richtext.fill", color: .wikiAccent)
                    StatCard(title: L.tr("stat.entities"), value: "\(store.entityCount)", icon: "person.text.rectangle.fill", color: .wikiEntity)
                    StatCard(title: L.tr("stat.concepts"), value: "\(store.conceptCount)", icon: "lightbulb.fill", color: .wikiConcept)
                    StatCard(title: L.tr("stat.sources"), value: "\(store.sourceCount)", icon: "doc.plaintext.fill", color: .wikiSource)
                }
                .padding(.horizontal)

                // 空知识库引导
                if store.pages.isEmpty {
                    VStack(spacing: 16) {
                        // 标题区
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.wikiAccent)
                            Text("快速上手")
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }

                        GuideStepRow(number: 1, text: "创建第一个知识页面", icon: "doc.badge.plus")
                        GuideStepRow(number: 2, text: "使用 [[页面名]] 建立双向链接", icon: "link")
                        GuideStepRow(number: 3, text: "在图谱中浏览知识关联", icon: "circle.hexagongrid.fill")
                        GuideStepRow(number: 4, text: "通过搜索快速定位内容", icon: "magnifyingglass")
                    }
                    .padding(20)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                }

                // 使用技巧（非空知识库时显示）
                if !store.pages.isEmpty {
                    HStack(spacing: 12) {
                        WikiGlow(icon: "lightbulb.fill", color: .wikiConcept, size: 24)

                        Text("编辑页面时输入 [[页面名]] 即可自动建立双向链接")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.wikiAccent)
                        Text(L.tr("quickStart"))
                            .font(.headline)
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    QuickActionRow(icon: "plus.circle.fill", title: L.tr("action.createPage"), subtitle: L.tr("action.createPage.subtitle"), color: .wikiAccent) {
                        showCreateSheet = true
                    }
                    QuickActionRow(icon: "tray.and.arrow.down.fill", title: L.tr("action.ingestKnowledge"), subtitle: L.tr("action.ingestKnowledge.subtitle"), color: .wikiSource) {
                        selectedTab = .ingest
                    }
                    QuickActionRow(icon: "circle.hexagongrid.fill", title: L.tr("action.browseGraph"), subtitle: L.tr("action.browseGraph.subtitle"), color: .wikiConcept) {
                        selectedTab = .graph
                    }
                    QuickActionRow(icon: "stethoscope", title: L.tr("action.healthCheck"), subtitle: L.tr("action.healthCheck.subtitle"), color: .wikiComparison) {
                        selectedTab = .settings
                    }
                }
                .padding(.horizontal)
                
                // Recent Pages
                if !store.pages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.wikiAccent)
                            Text(L.tr("recentUpdates"))
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(Array(store.pages.sorted { $0.updated > $1.updated }.prefix(5))) { page in
                            PageRowView(page: page, compact: true)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Pinned / Favorite Pages
                let pinnedPages = store.pages.filter { $0.isPinned }
                if !pinnedPages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            WikiGlow(icon: "pin.fill", color: .wikiAccent, size: 20)
                            Label(L.tr("pinned"), systemImage: "pin.fill")
                                .font(.headline)
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(pinnedPages) { page in
                            PageRowView(page: page, compact: true)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.wikiBackground)
        .sheet(isPresented: $showCreateSheet) {
            CreatePageView()
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            // 带发光效果的图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)

            Text(title)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Quick Action Row
struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 渐变图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: WikiUI.small)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary.opacity(0.6))
            }
            .padding(14)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
            .shadow(color: .black.opacity(isPressed ? 0.04 : 0.08), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

// MARK: - Guide Step Row
private struct GuideStepRow: View {
    let number: Int
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            // 带数字序号的渐变圆
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: .wikiAccent.opacity(0.3), radius: 4, x: 0, y: 2)

                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.wikiText)

            Spacer()
        }
    }
}

// MARK: - Page Row View
struct PageRowView: View {
    let page: WikiPage
    var compact: Bool = false
    @EnvironmentObject var store: KMStore
    
    var body: some View {
        Button(action: { store.selectedPageID = page.id }) {
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: page.displayIcon)
                    .font(.body)
                    .foregroundStyle(page.type.themedColor)
                    .frame(width: 32, height: 32)
                    .background(page.type.themedColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                        .lineLimit(1)
                    
                    if !compact {
                        HStack(spacing: 8) {
                            Text(page.type.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(page.type.themedColor.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(page.type.themedColor)
                            
                            Text(page.updated, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                            
                            if !page.tags.isEmpty {
                                Text(page.tags.prefix(2).joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(page.status.color)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
