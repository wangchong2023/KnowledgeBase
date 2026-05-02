import SwiftUI

// MARK: - Wiki Navigation (Main Wiki Browser)
@MainActor
struct NavigationView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    var heroNamespace: Namespace.ID
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        Group {
            // 统一使用两栏布局：sidebar（含页面列表）+ detail
            // 避免三栏布局中两个 List(selection:) 绑定同一个值导致点击失效
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(heroNamespace: heroNamespace)
                    #if os(macOS)
                    .background(.ultraThinMaterial)
                    #endif
            } detail: {
                DetailContentView(selectedTab: $selectedTab, tooltipManager: tooltipManager, heroNamespace: heroNamespace)
            }
            .navigationSplitViewStyle(.balanced)
            #if os(macOS)
            .toolbarBackground(.visible, for: .windowToolbar)
            #endif
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button(action: { columnVisibility = columnVisibility == .all ? .detailOnly : .all }) {
                    Image(systemName: "sidebar.left")
                }
                .help(Localized.tr("sidebar.toggle"))
            }
            #endif

            ToolbarItem(placement: .principal) {
                AIPulseIndicator()
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 12) {
                    #if os(macOS)
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        Label(Localized.tr("page.createPage"), systemImage: "plus")
                    }
                    .help(Localized.tr("page.createPage"))
                    #else
                    Button(action: {
                        showCreateSheet = true
                        if !tooltipManager.isShown(.createPage) {
                            withAnimation { tooltipManager.activeTooltip = .createPage }
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    #endif
                    
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
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
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


