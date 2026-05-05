// TagCloudView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的标签管理中心（TagCloudView）。
// 它作为全局标签的聚合展示与维护入口，具备以下核心能力：
// 1. 动态标签云：通过 FlowLayout 自动排列标签，并根据页面引用热度实时更新实时计数。
// 2. 增强型 CRUD 交互：支持标签的新增、重命名、单项删除及基于多选模式的批量删除。
// 3. 关联检索：点击标签可实时筛选并展示关联的 Wiki 页面，形成“标签 -> 内容”快速导航。
// 4. 视觉规范对齐：严格遵循系统的模块化 UI 语言，确保边框宽度与卡片间距在全平台一致。
// 版本: 1.3
// 修改记录:
//   - 2026-05-05: 修复标签云容器宽度未撑满导致边框与下方列表不齐的问题
//   - 2026-05-05: 完善详细中文文档注释，规范函数头
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - 标签云视图 (导航容器)
/// 标签管理的顶层视图容器，负责承载主内容
struct TagCloudView: View {
    /// 初始选中的标签（由外部跳转传入）
    var initialTag: String? = nil
    
    var body: some View {
        TagCloudViewContent(initialTag: initialTag)
    }
}

// MARK: - 标签管理主内容
/// 标签管理的核心业务逻辑与界面实现
struct TagCloudViewContent: View {
    // ── 外部依赖 ──
    @Environment(KMStore.self) var store
    
    // ── 交互状态 ──
    @State private var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var showDeleteConfirm = false
    @State private var tagToDelete: String?
    @State private var showAddTagDialog = false
    @State private var addTagName = ""
    
    // ── 批量管理 ──
    @State private var isEditMode = false
    @State private var selectedTagsForBulk = Set<String>()
    @State private var showBulkDeleteConfirm = false
    @State private var searchText = ""

    /// 数据源：所有标签及其引用计数
    @State private var tags: [(tag: String, count: Int)] = []

    /// 初始化路由状态
    /// - Parameter initialTag: 外部传入的初始选中标签
    init(initialTag: String? = nil) {
        _selectedTag = State(initialValue: initialTag)
    }
    
    /// 执行数据抓取
    private func fetchData() async {
        let allTags = await store.getAllTags()
        await MainActor.run {
            self.tags = allTags
        }
    }

    /// 经过搜索过滤后的标签列表
    var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    /// 基于选中标签筛选的页面列表
    var filteredPages: [WikiPage] {
        guard let tag = selectedTag else { return store.pages }
        return store.pages.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        mainContent
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("tag.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(alertLayer)
            .task {
                await fetchData()
            }
            .onChange(of: store.pages) { _, _ in
                Task { await fetchData() }
            }
    }

    /// 组合主界面布局
    private var mainContent: some View {
        VStack(spacing: 0) {
            // 1. 顶部操作栏
            HStack(spacing: 20) {
                Spacer()
                if !isEditMode {
                    Button(action: { showAddTagDialog = true }) {
                        Label(Localized.tr("tags.addNew"), systemImage: "plus.circle")
                            .font(.subheadline.bold())
                    }
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isEditMode.toggle()
                        if !isEditMode { selectedTagsForBulk.removeAll() }
                    }
                }) {
                    Label(isEditMode ? L10n.Common.tr("done") : Localized.tr("tags.manageTitle"), 
                          systemImage: isEditMode ? "checkmark.circle" : "checklist")
                        .font(.subheadline.bold())
                        .foregroundStyle(isEditMode ? .green : .wikiAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // 2. 标签云展示区（带标准边框的卡片）
            if tags.isEmpty {
                emptyTagsView
            } else {
                VStack(spacing: 0) {
                    tagScrollView
                }
                .frame(maxWidth: .infinity)
                .background(WikiUI.containerBackground)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                        .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                )
                .overlay(alignment: .bottom) {
                    if isEditMode && !selectedTagsForBulk.isEmpty {
                        bulkActionBar
                    }
                }
            }

            // 3. 关联页面列表（确保与上方卡片视觉对齐）
            pagesListView
                .background(WikiUI.containerBackground)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                        .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                )
        }
    }

    private var alertLayer: some View {
        Color.clear
            // 重命名对话框
            .alert(Localized.tr("tag.renameTag"), isPresented: Binding(
                get: { tagToRename != nil },
                set: { if !$0 { tagToRename = nil } }
            )) {
                TextField(Localized.tr("tag.newName"), text: $newTagName)
                Button(L10n.Common.tr("cancel"), role: .cancel) { tagToRename = nil }
                Button(L10n.Common.tr("ok")) {
                    performRename()
                }
            } message: {
                Text(Localized.trf("tag.renameMessage", tagToRename ?? ""))
            }
            // 删除确认对话框
            .confirmationDialog(
                tagToDelete.map { Localized.trf("tag.deleteMessage", $0) } ?? Localized.tr("tag.deleteTag"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.tr("delete"), role: .destructive) {
                    performDelete()
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { tagToDelete = nil }
            } message: {
                Text(Localized.tr("settings.clearAll.message"))
            }
            // 新增标签对话框 (保持 alert 因为需要文本输入)
            .alert(Localized.tr("tags.addNew"), isPresented: $showAddTagDialog) {
                TextField(Localized.tr("tags.inputName"), text: $addTagName)
                Button(L10n.Common.tr("cancel"), role: .cancel) { addTagName = "" }
                Button(L10n.Common.tr("create")) {
                    performAddTag()
                }
            } message: {
                Text(Localized.tr("tags.createHint"))
            }
            // 批量删除确认
            .confirmationDialog(
                Localized.trf("tags.bulkDeleteWarning", selectedTagsForBulk.count),
                isPresented: $showBulkDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.tr("deleteAll"), role: .destructive) {
                    store.bulkDeleteTags(selectedTagsForBulk)
                    HapticFeedback.shared.trigger(.success)
                    selectedTagsForBulk.removeAll()
                    isEditMode = false
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { }
            } message: {
                Text(Localized.tr("settings.clearAll.message"))
            }
    }

    // MARK: - 子视图组件



    private var bulkActionBar: some View {
        HStack {
            Text(Localized.trf("tags.selectedCount", selectedTagsForBulk.count))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Spacer()
            Button(role: .destructive, action: { showBulkDeleteConfirm = true }) {
                Text(L10n.Common.tr("bulkDelete"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(BlurView().background(Color.wikiAccent.opacity(0.8)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var emptyTagsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundStyle(.wikiSecondary)
            Text(Localized.tr("tag.noTags"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            Text(Localized.tr("tag.noTagsHint"))
                .font(.caption)
                .foregroundStyle(.wikiSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }

    private var tagScrollView: some View {
        ScrollView {
            FlowLayout(spacing: 12) {
                ForEach(filteredTags, id: \.tag) { tagItem in
                    tagCapsule(tagItem)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .frame(minHeight: 40)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 280)
    }

    private func tagCapsule(_ item: (tag: String, count: Int)) -> some View {
        let isSelected = isEditMode ? selectedTagsForBulk.contains(item.tag) : selectedTag == item.tag
        
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isEditMode {
                    if selectedTagsForBulk.contains(item.tag) {
                        selectedTagsForBulk.remove(item.tag)
                    } else {
                        selectedTagsForBulk.insert(item.tag)
                    }
                } else {
                    selectedTag = selectedTag == item.tag ? nil : item.tag
                }
            }
            HapticFeedback.shared.trigger(.selection)
        }) {
            HStack(spacing: 6) {
                Text("#\(item.tag)")
                    .font(.system(.subheadline, design: .rounded).weight(isSelected ? .semibold : .regular))
                
                Text("\(item.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.wikiAccent.opacity(0.15) : Color.wikiSecondary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.wikiAccent.opacity(0.08) : Color.wikiCard.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.wikiAccent.opacity(0.8) : Color.wikiBorder.opacity(0.6), lineWidth: 1.2)
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .shadow(color: isSelected ? Color.wikiAccent.opacity(0.12) : Color.clear, radius: 10, y: 4)
            .overlay(alignment: .topTrailing) {
                if isEditMode {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.wikiAccent : Color.wikiCard)
                            .frame(width: 18, height: 18)
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .stroke(Color.wikiBorder, lineWidth: 1)
                                .frame(width: 18, height: 18)
                        }
                    }
                    .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .wikiAccent : .wikiText)
        .contextMenu {
            if !isEditMode {
                Button(action: {
                    tagToRename = item.tag
                    newTagName = item.tag
                }) {
                    Label(Localized.tr("tag.rename"), systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    tagToDelete = item.tag
                    showDeleteConfirm = true
                }) {
                    Label(Localized.tr("tag.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var pagesListView: some View {
        Group {
            if let tag = selectedTag, !isEditMode {
                List {
                    Section {
                        ForEach(filteredPages) { page in
                            NavigationLink(destination: PageDetailView(page: page)) {
                                PageRowView(page: page, compact: true)
                                    .padding(.vertical, 4)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.wikiCard.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            )
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack {
                            Text(tag)
                                .font(.subheadline.bold())
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                            Text(Localized.trf("tag.tagPages", filteredPages.count))
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .textCase(nil)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isEditMode ? "checklist" : "tag")
                        .font(.system(size: 32))
                        .foregroundStyle(.wikiSecondary.opacity(0.5))
                    Text(isEditMode ? Localized.tr("tags.selectToManage") : Localized.tr("tagcloud.selectTag"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.wikiBackground.opacity(0.01)) // 响应点击
                .onTapGesture {
                    if isEditMode { isEditMode = false }
                }
            }
        }
    }

    // MARK: - 业务逻辑执行

    /**
     * @description: 执行标签重命名逻辑，同步更新 Wiki 页面引用及当前选中状态
     * @return {*}
     */
    private func performRename() {
        guard let old = tagToRename, !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        store.renameTag(old, to: trimmed)
        if selectedTag == old { selectedTag = trimmed }
        tagToRename = nil
    }

    /**
     * @description: 执行标签删除逻辑，并重置选中状态
     * @return {*}
     */
    private func performDelete() {
        if let tag = tagToDelete {
            store.deleteTag(tag)
            if selectedTag == tag { selectedTag = nil }
        }
        tagToDelete = nil
    }

    /**
     * @description: 创建新标签并自动设为选中状态
     * @return {*}
     */
    private func performAddTag() {
        let trimmed = addTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        store.addNewTag(trimmed)
        
        addTagName = ""
        showAddTagDialog = false
        selectedTag = trimmed
    }
}

// 简单的模糊背景视图 (macOS only)
#if os(macOS)
struct BlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = .hudWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#else
struct BlurView: View {
    var body: some View {
        Color.clear
    }
}
#endif

