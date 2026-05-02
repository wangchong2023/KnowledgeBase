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
    @State private var isKBExpanded: Bool = true

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
            // ══ 1. 仪表盘与核心能力 ══
            Section {
                NavigationLink(value: SidebarSelection.tool(.dashboard)) {
                    Label(Localized.tr("sidebar.dashboard"), systemImage: "gauge.with.needle.fill")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("dashboard")

                NavigationLink(value: SidebarSelection.tool(.chat)) {
                    Label(Localized.tr("tab.chat"), systemImage: "sparkles")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("AI-Chat")
                
                NavigationLink(value: SidebarSelection.tool(.taskCenter)) {
                    HStack {
                        Label(Localized.tr("aitask.center.title"), systemImage: "cpu.fill")
                        Spacer()
                        if TaskCenter.shared.unreadCount > 0 {
                            Text("\(TaskCenter.shared.unreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.red))
                        }
                    }
                }
            }
            
            // ══ 2. 知识宇宙 (分类管理) ══
            Section {
                // 全部页面
                NavigationLink(value: SidebarSelection.tool(.index)) {
                    Label(Localized.tr("sidebar.allPages"), systemImage: "tray.full.fill")
                }
                
                // 按类型分类 (折叠组)
                DisclosureGroup(isExpanded: $isKBExpanded) {
                    ForEach(PageType.allCases) { type in
                        let count = store.pages.filter { $0.type == type }.count
                        if count > 0 {
                            NavigationLink(value: SidebarSelection.tool(.index)) {
                                HStack {
                                    Label(type.displayName, systemImage: type.icon)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                            }
                        }
                    }
                } label: {
                    Label(Localized.tr("sidebar.navigation"), systemImage: "square.grid.2x2.fill")
                        .font(.subheadline.bold())
                }
            } header: {
                Text(Localized.tr("sidebar.universe"))
            }

            // ══ 3. 已收藏 ══
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
                }
            }

            // ══ 4. 智能工具 ══
            Section {
                NavigationLink(value: SidebarSelection.tool(.lint)) {
                    HStack {
                        Label(Localized.tr("sidebar.healthCheck"), systemImage: "stethoscope")
                        Spacer()
                        if !store.lintIssues.isEmpty {
                            Text("\(store.lintIssues.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .background(Color.wikiAccent.opacity(0.1))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiAccent)
                        }
                    }
                }

                NavigationLink(value: SidebarSelection.tool(.tagCloud)) {
                    Label(Localized.tr("sidebar.tagManager"), systemImage: "tag.fill")
                }

                NavigationLink(value: SidebarSelection.tool(.weeklyReport)) {
                    Label(Localized.tr("sidebar.weeklyInsight"), systemImage: "doc.text.magnifyingglass")
                }
            } header: {
                Text(Localized.tr("sidebar.tools"))
            }

            // ══ 5. 扩展 ══
            Section {
                NavigationLink(value: SidebarSelection.tool(.pluginMarket)) {
                    Label(Localized.tr("sidebar.pluginMarket"), systemImage: "puzzlepiece.extension.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(Localized.tr("app.name"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
}

// MARK: - Page Sidebar Row
struct PageSidebarRow: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID
    @EnvironmentObject var store: KMStore

    private var snippet: String? {
        let stripped = page.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map { line -> String in
                var s = String(line)
                s = s.replacingOccurrences(of: #"^[#\-\*\>\s]+"#, with: "", options: .regularExpression)
                return s.trimmingCharacters(in: .whitespaces)
            } ?? ""
        return stripped.isEmpty ? nil : stripped
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: page.displayIcon)
                .font(.system(size: 14))
                .foregroundStyle(page.type.themedColor)
                .frame(width: 28, height: 28)
                .background(page.type.themedColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let snippet = snippet {
                    Text(snippet)
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
