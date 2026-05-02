import SwiftUI

// MARK: - 侧边栏导航中心
/// 应用的核心导航枢纽，负责在一级菜单、二级工具列表与三级详情页之间进行路由分发。

enum SidebarSelection: Hashable {
    case page(UUID)
    case tool(KMStore.ToolItem)
}

struct SidebarView: View {
    @EnvironmentObject var store: KMStore
    var heroNamespace: Namespace.ID

    /// iPad 两栏布局时当前选中的类型过滤器
    @State private var selectedType: PageType? = nil

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: {
                if let tool = store.selectedTool { return .tool(tool) }
                if let id = store.selectedPageID { return .page(id) }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .page(let id):
                    store.selectedTool = nil
                    store.selectedPageID = id
                case .tool(let tool):
                    store.selectedPageID = nil
                    store.selectedTool = tool
                case .none:
                    store.selectedPageID = nil
                    store.selectedTool = nil
                }
            }
        )
    }

    var body: some View {
        List(selection: selectionBinding) {
            // ══ 知识仪表盘（顶部入口）══
            NavigationLink(value: SidebarSelection.tool(.dashboard)) {
                Label(Localized.tr("sidebar.dashboard"), systemImage: "gauge.with.needle.fill")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("dashboard")

            // ══ 页面列表：顶部横向 FilterChips + 扁平列表 ══
            embeddedFilterSection

            // ── 导航：总索引、AI 助手、操作日志 ──
            Section {
                NavigationLink(value: SidebarSelection.tool(.index)) {
                    Label(Localized.tr("sidebar.masterIndex"), systemImage: "list.dash")
                        .foregroundStyle(.wikiText)
                }
                .accessibilityIdentifier("masterIndex")

                NavigationLink(value: SidebarSelection.tool(.chat)) {
                    Label(Localized.tr("tab.chat"), systemImage: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(.wikiText)
                }
                .accessibilityIdentifier("AI-Chat")

                NavigationLink(value: SidebarSelection.tool(.log)) {
                    Label(Localized.tr("sidebar.operationLog"), systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.wikiText)
                }
                .accessibilityIdentifier("operationLog")

                NavigationLink(value: SidebarSelection.tool(.taskCenter)) {
                    HStack {
                        Label(Localized.tr("aitask.center.title"), systemImage: "cpu.fill")
                            .foregroundStyle(.wikiText)
                        Spacer()
                        if TaskCenter.shared.unreadCount > 0 {
                            Text("\(TaskCenter.shared.unreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.red))
                        } else if !TaskCenter.shared.tasks.filter({ if case .running = $0.status { return true }; return false }).isEmpty {
                            Circle()
                                .fill(.wikiAccent)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .accessibilityIdentifier("taskCenter")
            } header: {
                Text(Localized.tr("sidebar.navigation"))
                    .foregroundStyle(.wikiSecondary)
            }
            
            // ── 已收藏 ──
            let pinnedPages = store.pages.filter { $0.isPinned }
            if !pinnedPages.isEmpty {
                Section {
                    ForEach(pinnedPages) { page in
                        NavigationLink(value: SidebarSelection.page(page.id)) {
                            PageSidebarRow(page: page, heroNamespace: heroNamespace)
                        }
                    }
                } header: {
                    Label(Localized.tr("pinned"), systemImage: "pin.fill")
                        .foregroundStyle(.wikiText)
                }
            }

            // ── 工具 ──
            Section {
                NavigationLink(value: SidebarSelection.tool(.lint)) {
                    HStack {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.wikiText)
                        Text(Localized.tr("sidebar.healthCheck"))
                            .foregroundStyle(.wikiText)
                        Spacer()
                        if !store.lintIssues.isEmpty {
                            Text("\(store.lintIssues.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.wikiAccent.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiAccent)
                        }
                    }
                }
                .accessibilityIdentifier("healthCheck")

                NavigationLink(value: SidebarSelection.tool(.tagCloud)) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.wikiText)
                        Text(Localized.tr("sidebar.tagManager"))
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                }
                .accessibilityIdentifier("tagCloud")

                NavigationLink(value: SidebarSelection.tool(.collab)) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.wikiText)
                        Text(Localized.tr("tab.collab"))
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                }
                .accessibilityIdentifier("collab")

                NavigationLink(value: SidebarSelection.tool(.weeklyReport)) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.wikiText)
                        Text(Localized.tr("sidebar.weeklyInsight"))
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                }
                .accessibilityIdentifier("weeklyInsight")
            } header: {
                Text(Localized.tr("sidebar.tools"))
                    .foregroundStyle(.wikiSecondary)
            }

            NavigationLink(value: SidebarSelection.tool(.pluginMarket)) {
                Label(Localized.tr("sidebar.pluginMarket"), systemImage: "puzzlepiece.extension.fill")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("pluginMarket")

        }
        .listStyle(.sidebar)
        .navigationTitle(Localized.tr("app.name"))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: { store.securityService.lock() }) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text(Localized.tr("security.lockVault"))
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().stroke(Color.wikiBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }

    }

    // MARK: - Embedded Filter Chips (iPad two-column layout)
    @ViewBuilder
    private var embeddedFilterSection: some View {
        Section {
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
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))

            // ── 扁平页面列表（不再按类型折叠，由 FilterChips 过滤） ──
            let filteredPages = selectedType == nil
                ? store.pages
                : store.pages.filter { $0.type == selectedType }

            ForEach(filteredPages) { page in
                NavigationLink(value: SidebarSelection.page(page.id)) {
                    PageListRow(page: page, heroNamespace: heroNamespace)
                }
            }
        }
    }

}

// MARK: - Page Sidebar Row
struct PageSidebarRow: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID
    @EnvironmentObject var store: KMStore

    /// 内容摘要：取正文第一行非空文字（去掉 Markdown 标记符）
    private var snippet: String? {
        let stripped = page.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { line -> String in
                var s = String(line)
                // 去掉常见 Markdown 前缀：# ## ### - * >
                s = s.replacingOccurrences(of: #"^[#\-\*\>\s]+"#,
                                            with: "",
                                            options: .regularExpression)
                return s.trimmingCharacters(in: .whitespaces)
            } ?? ""
        return stripped.isEmpty ? nil : stripped
    }

    /// 字数展示：超过 1000 显示 k
    private var wordCountLabel: String {
        let n = page.wordCount
        return n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左侧：类型图标 + 状态色点
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: page.displayIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(page.type.themedColor)
                        .matchedGeometryEffect(id: page.id, in: heroNamespace)
                        .frame(width: 30, height: 30)
                        .background(page.type.themedColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.sidebarRadius))

                    Circle()
                        .fill(page.status.color)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: 2)
                }

                // 右侧：主标题 + 摘要 + 元数据行
                VStack(alignment: .leading, spacing: 3) {
                    // 标题行
                    HStack(spacing: 4) {
                        Text(page.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.wikiText)
                            .lineLimit(1)

                        if page.isStub {
                            Text(Localized.tr("status.stub"))
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.yellow)
                        }

                        if page.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.wikiComparison)
                        }
                    }

                    // 摘要（有内容时才显示）
                    if let snippet = snippet {
                        Text(snippet)
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                            .lineLimit(1)
                    }

                    // 元数据行：字数 · 出链数 · 标签
                    HStack(spacing: 6) {
                        // 字数
                        if page.wordCount > 0 {
                            Label(wordCountLabel, systemImage: "text.alignleft")
                                .font(.system(size: 10))
                                .foregroundStyle(.wikiSecondary.opacity(0.8))
                        }

                        // 出链数
                        let linkCount = page.outgoingLinks.count
                        if linkCount > 0 {
                            Label("\(linkCount)", systemImage: "link")
                                .font(.system(size: 10))
                                .foregroundStyle(.wikiSecondary.opacity(0.8))
                        }

                        // 最多显示 2 个标签
                        ForEach(page.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.wikiSecondary.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiSecondary.opacity(0.7))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
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
        .onTapGesture(perform: action)
    }
}

// MARK: - Page List Row (for embedded page list in SidebarView on iPad)
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
                                .foregroundStyle(.wikiSecondary.opacity(0.8))
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
            .contentShape(Rectangle())
    }
}
