import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            if let pageID = store.selectedPageID,
               let page = store.pageByID(pageID) {
                PageDetailView(page: page)
            } else {
                WikiWelcomeView(selectedTab: $selectedTab)
            }
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
                Button(action: { showCreateSheet = true }) {
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
                // Hero
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.wikiAccent, .wikiConcept],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
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
                        Text("快速上手")
                            .font(.headline)
                            .foregroundStyle(.wikiText)

                        GuideStepRow(number: 1, text: "创建第一个知识页面", icon: "doc.badge.plus")
                        GuideStepRow(number: 2, text: "使用 [[页面名]] 建立双向链接", icon: "link")
                        GuideStepRow(number: 3, text: "在图谱中浏览知识关联", icon: "circle.hexagongrid.fill")
                        GuideStepRow(number: 4, text: "通过搜索快速定位内容", icon: "magnifyingglass")
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // 使用技巧（非空知识库时显示）
                if !store.pages.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(.wikiConcept)
                        Text("编辑页面时输入 [[页面名]] 即可自动建立双向链接")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.wikiConcept.opacity(0.06))
                    .clipShape(Capsule())
                    .padding(.horizontal)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.tr("quickStart"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
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
                        Text(L.tr("recentUpdates"))
                            .font(.headline)
                            .foregroundStyle(.wikiText)
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
                        Label(L.tr("pinned"), systemImage: "pin.fill")
                            .font(.headline)
                            .foregroundStyle(.wikiAccent)
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)
            Text(title)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Action Row
struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Guide Step Row
private struct GuideStepRow: View {
    let number: Int
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.opacity(0.15))
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.wikiAccent)
            }
            .frame(width: 28, height: 28)

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
