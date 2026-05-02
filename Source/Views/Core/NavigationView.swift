import SwiftUI

// MARK: - Wiki Navigation (Main Wiki Browser)
struct NavigationView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared
    @Namespace private var heroNamespace

    var body: some View {
        Group {
            // 统一使用两栏布局：sidebar（含页面列表）+ detail
            // 避免三栏布局中两个 List(selection:) 绑定同一个值导致点击失效
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(heroNamespace: heroNamespace)
            } detail: {
                DetailContentView(selectedTab: $selectedTab, tooltipManager: tooltipManager, heroNamespace: heroNamespace)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                AIPulseIndicator()
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        store.undo()
                    } label: {
                        Label(Localized.tr("undo.undo"), systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!store.undoService.canUndo)

                    Button {
                        store.redo()
                    } label: {
                        Label(Localized.tr("undo.redo"), systemImage: "arrow.uturn.forward")
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

// MARK: - Detail Content (tools / page detail / welcome, driven by store.selectedTool)
struct DetailContentView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @ObservedObject var tooltipManager: TooltipManager
    var heroNamespace: Namespace.ID

    var body: some View {
        ZStack {
            // Primary content: tool views take priority, then page detail, then welcome
            Group {
                if let tool = store.selectedTool {
                    toolView(for: tool)
                } else if let pageID = store.selectedPageID,
                          let page = store.pages.first(where: { $0.id == pageID }) {
                    PageDetailView(page: page, heroNamespace: heroNamespace)
                } else {
                    WelcomeView(selectedTab: $selectedTab)
                }
            }

            // Tooltip overlay (only shown when on WelcomeView / page detail)
            if tooltipManager.activeTooltip == .createPage && store.selectedTool == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            WikiTooltip(
                                title: Localized.tr(tooltipManager.activeTooltip?.titleKey ?? ""),
                                description: Localized.tr(tooltipManager.activeTooltip?.descriptionKey ?? ""),
                                icon: tooltipManager.activeTooltip?.icon ?? "questionmark",
                                arrowDirection: .bottom,
                                accentColor: .wikiAccent
                            )
                            Button(action: {
                                withAnimation { tooltipManager.activeTooltip = nil }
                            }) {
                                Text(Localized.tr("misc.gotIt"))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: tooltipManager.activeTooltip)
    }

    @ViewBuilder
    private func toolView(for tool: KMStore.ToolItem) -> some View {
        switch tool {
        case .index:
            IndexView()
        case .chat:
            ChatView()
        case .log:
            LogView()
        case .lint:
            LintView()
        case .tagCloud:
            TagCloudView()
        case .collab:
            CollaborationView()
        case .taskCenter:
            TaskCenterView()
        case .weeklyReport:
            WeeklyReportView()
        case .dashboard:
            KnowledgeDashboardView()
        case .pluginMarket:
            PluginCenterView()
        }
    }
}

// MARK: - Middle Column (always shows page list)
struct MiddleColumnView: View {
    @EnvironmentObject var store: KMStore
    var heroNamespace: Namespace.ID
    @State private var selectedType: PageType? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // Type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: Localized.tr("sidebar.allPages"),
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )
                    .accessibilityIdentifier("filterAll")

                    ForEach(PageType.allCases) { type in
                        let count = store.pages.filter { $0.type == type }.count
                        if count > 0 {
                            FilterChip(
                                title: type.displayName,
                                icon: type.icon,
                                count: count,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                            .accessibilityIdentifier("filter\(type.rawValue.capitalized)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.wikiBackground)

            Divider()

            // Pages list
            List(selection: $store.selectedPageID) {
                let filteredPages = selectedType == nil
                    ? store.pages
                    : store.pages.filter { $0.type == selectedType }

                ForEach(filteredPages) { page in
                    PageListRow(page: page, heroNamespace: heroNamespace)
                        .tag(page.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    store.deletePage(page)
                                    if store.selectedPageID == page.id {
                                        store.selectedPageID = nil
                                    }
                                }
                            } label: {
                                Label(Localized.tr("misc.delete"), systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle(Localized.tr("sidebar.allPages"))
            }
        }
    }
}

