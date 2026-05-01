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

    /// 本地副本，用于驱动 SwiftUI body 重新求值
    @State private var detailPageID: UUID?
    @State private var detailTool: KMStore.ToolItem?

    var body: some View {
        ZStack {
            // Primary content: tool views take priority, then page detail, then welcome
            Group {
                if detailTool != nil,
                   let tool = detailTool {
                    toolView(for: tool)
                } else if let pageID = store.selectedPageID,
                          let page = store.pageByID(pageID) {
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
        .onChange(of: store.selectedPageID) { _, newID in
            detailPageID = newID
        }
        .onChange(of: store.selectedTool) { _, newTool in
            detailTool = newTool
        }
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
            AITaskCenterView()
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
                                    store.deletePage(page) { id in
                                        if store.selectedPageID == id {
                                            store.selectedPageID = nil
                                            return true
                                        }
                                        return false
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

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下标题字号从 15pt 提升到 17pt
    private var titleFont: Font {
        horizontalSizeClass == .regular ? .body : .subheadline
    }

    /// iPad 大屏幕下计数徽章从 10pt 提升到 12pt
    private var countFont: Font {
        horizontalSizeClass == .regular ? .caption : .caption2
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(titleFont)
                if let count = count {
                    Text("\(count)")
                        .font(countFont)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.wikiAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.wikiAccent : Color.wikiCard)
            .foregroundStyle(isSelected ? .white : .wikiText)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Page List Row (for middle column)
struct PageListRow: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID
    @EnvironmentObject var store: KMStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var wordCountLabel: String {
        let n = page.wordCount
        return n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    /// iPad 大屏幕下元数据行字号从 10pt 升到 12pt
    private var metaFont: Font {
        horizontalSizeClass == .regular ? .system(size: 12) : .system(size: 10)
    }

    /// iPad 大屏幕下 Stub 标签从 9pt 升到 10pt
    private var stubFont: Font {
        horizontalSizeClass == .regular ? .system(size: 10) : .system(size: 9)
    }

    var body: some View {
        Button(action: {
            store.selectedTool = nil
            store.selectedPageID = page.id
        }) {
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: page.displayIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(page.type.themedColor)
                    .matchedGeometryEffect(id: page.id, in: heroNamespace)
                    .frame(width: 36, height: 36)
                    .background(page.type.themedColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))

                // Title and metadata
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(page.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.wikiText)
                            .lineLimit(1)

                        if page.isStub {
                            Text(Localized.tr("status.stub"))
                                .font(stubFont)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.yellow)
                        }
                    }

                    HStack(spacing: 8) {
                        Label(wordCountLabel, systemImage: "text.alignleft")
                            .font(metaFont)
                            .foregroundStyle(.wikiSecondary.opacity(0.8))

                        if page.outgoingLinks.count > 0 {
                            Label("\(page.outgoingLinks.count)", systemImage: "link")
                                .font(metaFont)
                                .foregroundStyle(.wikiAccent.opacity(0.8))
                        }

                        Text(page.type.displayName)
                            .font(metaFont)
                            .foregroundStyle(page.type.themedColor.opacity(0.8))
                    }
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(page.status.color)
                    .frame(width: 8, height: 8)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
}
