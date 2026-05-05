// SidebarView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的核心导航分发中心（SidebarView），负责在多层级视图间建立稳健的路由关联。
// 视图通过深度集成 SwiftUI 的 List 选择机制与 SceneStorage，提供了卓越的导航体验：
// 1. 三级路由调度：支持一级仪表盘能力、二级知识宇宙分类及三级页面详情的透明跳转，实现了基于有效绑定的单向数据流。
// 2. 场景化状态恢复：利用 @SceneStorage 自动持久化侧边栏的选中状态与折叠配置，确保应用重启或多窗口切换时的 Platinum 级体验。
// 3. 动态元数据集成：实时展示页面分类计数、健康检查问题统计及 AI 任务队列进度，将侧边栏转化为一个综合性的系统状态看板。
// 4. 原生交互增强：内置了针对 macOS 的文件拖拽导入、iOS 触感反馈及上下文菜单（Context Menu），支持收藏与删除等快捷操作。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化侧边栏图标尺寸与圆角常量
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - 侧边栏导航中心
/// 应用的核心导航枢纽，负责在一级菜单、二级工具列表与三级详情页之间进行路由分发。

enum SidebarSelection: Hashable {
    case page(UUID)
    case tool(KMStore.ToolItem)
    case filteredIndex(PageType)
    
    /// 将侧边栏选择映射为路由目标
    func asRoute() -> AppRoute {
        switch self {
        case .page(let id): return .pageDetail(id: id)
        case .tool(let tool):
            switch tool {
            case .dashboard: return .dashboard
            case .index: return .index()
            case .lint: return .lint
            case .taskCenter: return .taskCenter
            case .tagCloud: return .tagCloud
            case .chat: return .chat
            case .synthesis: return .synthesis
            case .weeklyReport: return .weeklyReport
            case .log: return .log
            case .collab: return .collab
            default: return .index()
            }
        case .filteredIndex(let type): return .index(filterType: type)
        }
    }
}

struct SidebarView: View {
    @Environment(KMStore.self) var store
    @Environment(IngestStore.self) var ingestStore
    @Environment(AppRouter.self) var router
    @ObservedObject var taskCenter = TaskCenter.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var heroNamespace: Namespace.ID
    var selection: Binding<SidebarSelection?>? = nil
    
    @State private var showDeleteConfirmation = false
    @State private var pageToDelete: WikiPage?

    /// 状态恢复 (Platinum Experience Item #3)
    @SceneStorage("sidebar.selectedPageID") private var restoredPageID: String?
    @SceneStorage("sidebar.selectedTool") private var restoredTool: String?
    @SceneStorage("sidebar.isRecentExpanded") private var isRecentExpanded: Bool = true

    /// 合并外部绑定与 AppRouter 状态
    private var effectiveBinding: Binding<SidebarSelection?> {
        @Bindable var router = router
        return $router.sidebarSelection
    }

    /// 将路由状态同步到 SceneStorage
    private func syncToSceneStorage(_ selection: SidebarSelection?) {
        switch selection {
        case .page(let id):
            restoredTool = nil
            restoredPageID = id.uuidString
        case .tool(let tool):
            restoredPageID = nil
            restoredTool = tool.rawValue
        case .filteredIndex:
            restoredPageID = nil
            restoredTool = nil
        case .none:
            restoredPageID = nil
            restoredTool = nil
        }
    }
    
    /// 从 SceneStorage 恢复路由状态
    private func restoreFromSceneStorage() {
        if let idStr = restoredPageID, let id = UUID(uuidString: idStr) {
            router.sidebarSelection = .page(id)
        } else if let toolStr = restoredTool, let tool = KMStore.ToolItem(rawValue: toolStr) {
            router.sidebarSelection = .tool(tool)
        } else {
            router.sidebarSelection = .tool(.index)
        }
    }

    var body: some View {
        List(selection: effectiveBinding) {
            // ══ 1. 仪表盘与核心能力 ══
            Section {
                NavigationLink(value: SidebarSelection.tool(.dashboard)) {
                    Label(Localized.tr("sidebar.dashboard"), systemImage: "gauge.with.needle.fill")
                }
                .accessibilityIdentifier("dashboard")

                NavigationLink(value: SidebarSelection.tool(.chat)) {
                    Label(Localized.tr("tab.chat"), systemImage: "sparkles")
                }
                .accessibilityIdentifier("AI-Chat")
                
                NavigationLink(value: SidebarSelection.tool(.synthesis)) {
                    Label(Localized.tr("sidebar.synthesis"), systemImage: "wand.and.stars")
                }

                NavigationLink(value: SidebarSelection.tool(.weeklyReport)) {
                    Label(Localized.tr("sidebar.weeklyInsight"), systemImage: "doc.text.magnifyingglass")
                }
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
                        NavigationLink(value: SidebarSelection.filteredIndex(type)) {
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

                NavigationLink(value: SidebarSelection.tool(.taskCenter)) {
                    HStack {
                        Label(L10n.AI.Task.centerTitle, systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if taskCenter.unreadCount > 0 {
                            Text("\(taskCenter.unreadCount)")
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
        .confirmationDialog(
            pageToDelete.map { Localized.trf("page.deletePageTitle", $0.title) } ?? Localized.tr("page.deletePage"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(Localized.tr("page.deletePage"), role: .destructive) {
                if let page = pageToDelete {
                    store.deletePage(page)
                    HapticFeedback.shared.trigger(.success)
                }
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {
                pageToDelete = nil
            }
        } message: {
            Text(L10n.Settings.tr("clearAll.message")) // 复用不可恢复的警告文案
        }
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
                    HapticFeedback.shared.trigger(.selection)
                    store.securityService.lock()
                }) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .help(Localized.tr("security.lockVault"))
            }
        }
        .onAppear {
            restoreFromSceneStorage()
            
            // 在 iPhone (Compact) 模式下，返回侧边栏时清空选中高亮，避免视觉上的“固定选中”感
            if horizontalSizeClass == .compact {
                router.sidebarSelection = nil
            }
        }
        .onChange(of: router.sidebarSelection) { _, newValue in
            syncToSceneStorage(newValue)
        }
    }
    
    #if os(macOS)
    private func importDroppedFiles(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                if let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    Task { @MainActor in
                        ingestStore.importFile(at: url)
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
            // macOS 新窗口功能预留
        }) {
            Label(L10n.Common.tr("openInNewWindow"), systemImage: "macwindow.badge.plus")
        }
        #endif
        
        Divider()
        
        Button(role: .destructive, action: {
            pageToDelete = page
            showDeleteConfirmation = true
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
