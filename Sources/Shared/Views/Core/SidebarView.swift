import SwiftUI

// MARK: - 侧边栏导航中心
/// 应用的核心导航枢纽，负责在一级菜单、二级工具列表与三级详情页之间进行路由分发。

enum SidebarSelection: Hashable {
    case page(UUID)
    case tool(KMStore.ToolItem)
}

struct SidebarView: View {
    @Environment(KMStore.self) var store
    var heroNamespace: Namespace.ID

    /// 状态恢复 (Platinum Experience Item #3)
    @SceneStorage("sidebar.selectedPageID") private var restoredPageID: String?
    @SceneStorage("sidebar.selectedTool") private var restoredTool: String?
    @SceneStorage("sidebar.isRecentExpanded") private var isRecentExpanded: Bool = true

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: {
                if let toolStr = restoredTool, let tool = KMStore.ToolItem(rawValue: toolStr) { return .tool(tool) }
                if let idStr = restoredPageID, let id = UUID(uuidString: idStr) { return .page(id) }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .page(let id):
                    restoredTool = nil
                    restoredPageID = id.uuidString
                    store.selectedPageID = id
                    store.selectedTool = nil
                case .tool(let tool):
                    restoredPageID = nil
                    restoredTool = tool.rawValue
                    store.selectedTool = tool
                    store.selectedPageID = nil
                case .none:
                    restoredPageID = nil
                    restoredTool = nil
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
                

            } header: {
                Text(Localized.tr("sidebar.capabilities"))
            }
            
            // ══ 2. 知识宇宙 (分类管理) ══
            Section {
                // 全部页面
                NavigationLink(value: SidebarSelection.tool(.index)) {
                    Label(Localized.tr("sidebar.allPages"), systemImage: "tray.full.fill")
                }
                
                // 按类型直接展示 (去除折叠嵌套，保持扁平清晰)
                ForEach(PageType.allCases) { type in
                    let count = store.pages.filter { $0.type == type }.count
                    if count > 0 {
                        NavigationLink(value: SidebarSelection.tool(.index)) {
                            Label {
                                HStack {
                                    Text(type.displayName)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                            } icon: {
                                Image(systemName: type.icon)
                                    .frame(width: 20, alignment: .center)
                            }
                        }
                    }
                }
            } header: {
                Text(Localized.tr("sidebar.universe"))
            }



            // ══ 4. 已收藏 ══
            let pinnedPages = store.pages.filter { $0.isPinned }
            if !pinnedPages.isEmpty {
                Section {
                    ForEach(pinnedPages) { page in
                        NavigationLink(value: SidebarSelection.page(page.id)) {
                            PageSidebarRow(page: page, heroNamespace: heroNamespace)
                        }
                        .contextMenu {
                            sidebarContextMenu(for: page)
                        }
                    }
                } header: {
                    Label(Localized.tr("pinned"), systemImage: "pin.fill")
                }
            }

            // ══ 5. 智能工具 ══
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

                NavigationLink(value: SidebarSelection.tool(.synthesis)) {
                    Label(Localized.tr("sidebar.synthesis"), systemImage: "wand.and.stars")
                }

                NavigationLink(value: SidebarSelection.tool(.weeklyReport)) {
                    Label(Localized.tr("sidebar.weeklyInsight"), systemImage: "doc.text.magnifyingglass")
                }

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


            } header: {
                Text(Localized.tr("sidebar.tools"))
            }
        }
        .listStyle(.sidebar)
        #if os(macOS)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            importDroppedFiles(providers: providers)
            return true
        }
        #endif
        .navigationTitle(Localized.tr("sidebar.title"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    HapticManager.shared.trigger(.selection)
                    store.securityService.lock()
                }) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .help(Localized.tr("security.lockVault"))
            }
        }
    }
    
    #if os(macOS)
    private func importDroppedFiles(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in
                        LogService.shared.debug("📥 [Mac] 正在导入拖拽文件：\(url.lastPathComponent)")
                        if let content = try? String(contentsOf: url) {
                            IngestQueue.shared.enqueue(title: url.deletingPathExtension().lastPathComponent, content: content, store: store)
                        }
                    }
                }
            }
        }
    }
    #endif
    
    @ViewBuilder
    private func sidebarContextMenu(for page: WikiPage) -> some View {
        Button(action: {
            var p = page
            p.isPinned.toggle()
            store.updatePage(p, forceDeepScan: false)
        }) {
            Label(page.isPinned ? Localized.tr("page.unpin") : Localized.tr("page.pin"), systemImage: page.isPinned ? "pin.slash" : "pin")
        }
        
        #if os(macOS)
        Button(action: {
            LogService.shared.debug("🖥️ [macOS] 正在新窗口打开页面：\(page.title)")
        }) {
            Label(Localized.tr("misc.openInNewWindow"), systemImage: "macwindow.badge.plus")
        }
        #endif
        
        Divider()
        
        Button(role: .destructive, action: {
            store.deletePage(page)
        }) {
            Label(Localized.tr("page.deletePage"), systemImage: "trash")
        }
    }
}

// MARK: - Page Sidebar Row
struct PageSidebarRow: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID
    @Environment(KMStore.self) var store

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
