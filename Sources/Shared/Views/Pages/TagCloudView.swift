import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - 标签云视图 (导航容器)
struct TagCloudView: View {
    var initialTag: String? = nil
    var body: some View {
        TagCloudViewContent(initialTag: initialTag)
    }
}

// MARK: - 标签管理主内容
struct TagCloudViewContent: View {
    @Environment(KMStore.self) var store
    @State private var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var showDeleteConfirm = false
    @State private var tagToDelete: String?
    @State private var showAddTagDialog = false
    @State private var addTagName = ""
    
    init(initialTag: String? = nil) {
        _selectedTag = State(initialValue: initialTag)
    }
    
    // 批量管理状态
    @State private var isEditMode = false
    @State private var selectedTagsForBulk = Set<String>()
    @State private var showBulkDeleteConfirm = false

    /// 从存储中心获取所有标签及其计数
    @State private var tags: [(tag: String, count: Int)] = []

    private func fetchData() async {
        let allTags = await store.getAllTags()
        await MainActor.run {
            self.tags = allTags
        }
    }

    /// 根据选中的标签筛选页面
    var filteredPages: [WikiPage] {
        guard let tag = selectedTag else { return store.pages }
        return store.pages.filter { $0.tags.contains(tag) }
    }

    var body: some View {
        mainContent
            .background(Color.wikiBackground)
            .navigationTitle(isEditMode ? Localized.tr("tags.manageTitle") : Localized.tr("tag.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        // 编辑模式开关
                        Button(action: {
                            withAnimation {
                                isEditMode.toggle()
                                if !isEditMode { selectedTagsForBulk.removeAll() }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isEditMode ? "checkmark.circle.fill" : "checklist")
                                Text(isEditMode ? Localized.tr("misc.done") : Localized.tr("tags.bulkManage"))
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.wikiAccent.opacity(0.1))
                        .clipShape(Capsule())
                        
                        if !isEditMode {
                            Button(action: { showAddTagDialog = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(Localized.tr("misc.add"))
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.wikiAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.wikiAccent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .background(alertLayer)
            .task {
                await fetchData()
            }
            .onChange(of: store.pages) { oldValue, newValue in
                Task { await fetchData() }
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // 顶部标签云展示区
            if tags.isEmpty {
                emptyTagsView
            } else {
                tagScrollView
                    .overlay(alignment: .bottom) {
                        if isEditMode && !selectedTagsForBulk.isEmpty {
                            bulkActionBar
                        }
                    }
            }

            Divider().background(Color.wikiBorder)

            // 下方页面列表区
            pagesListView
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
                Button(Localized.tr("misc.cancel"), role: .cancel) { tagToRename = nil }
                Button(Localized.tr("misc.ok")) {
                    performRename()
                }
            } message: {
                Text(Localized.trf("tag.renameMessage", tagToRename ?? ""))
            }
            // 删除确认对话框
            .alert(Localized.tr("tag.deleteTag"), isPresented: $showDeleteConfirm) {
                Button(Localized.tr("misc.cancel"), role: .cancel) { tagToDelete = nil }
                Button(Localized.tr("misc.delete"), role: .destructive) {
                    performDelete()
                }
            } message: {
                Text(Localized.trf("tag.deleteMessage", tagToDelete ?? ""))
            }
            // 新增标签对话框
            .alert(Localized.tr("tags.addNew"), isPresented: $showAddTagDialog) {
                TextField(Localized.tr("tags.inputName"), text: $addTagName)
                Button(Localized.tr("misc.cancel"), role: .cancel) { addTagName = "" }
                Button(Localized.tr("misc.create")) {
                    performAddTag()
                }
            } message: {
                Text(Localized.tr("tags.createHint"))
            }
            // 批量删除确认
            .alert(Localized.tr("tags.confirmBulkDelete"), isPresented: $showBulkDeleteConfirm) {
                Button(Localized.tr("misc.cancel"), role: .cancel) { }
                Button(Localized.tr("misc.deleteAll"), role: .destructive) {
                    for tag in selectedTagsForBulk {
                        store.deleteTag(tag)
                    }
                    selectedTagsForBulk.removeAll()
                    isEditMode = false
                }
            } message: {
                Text(Localized.trf("tags.bulkDeleteWarning", selectedTagsForBulk.count))
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
                Text(Localized.tr("misc.bulkDelete"))
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
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.tag) { tagItem in
                    tagCapsule(tagItem)
                }
            }
            .padding()
        }
    }

    private func tagCapsule(_ item: (tag: String, count: Int)) -> some View {
        let isSelected = isEditMode ? selectedTagsForBulk.contains(item.tag) : selectedTag == item.tag
        
        return Button(action: {
            withAnimation(.spring(response: 0.3)) {
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
        }) {
            HStack(spacing: 4) {
                Text("#\(item.tag)")
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                Text("\(item.count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.wikiAccent.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16) // 始终保持一致的间距
            .padding(.vertical, 8)
            .background(isSelected ? Color.wikiAccent.opacity(0.15) : Color.wikiCard)
            .overlay(
                RoundedRectangle(cornerRadius: 100) // 使用大圆角
                    .stroke(isSelected ? Color.wikiAccent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .clipShape(Capsule())
            .overlay(alignment: .topTrailing) {
                if isEditMode && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.wikiAccent)
                        .background(Circle().fill(Color.wikiCard))
                        .offset(x: 6, y: -6)
                } else if isEditMode {
                    Circle()
                        .stroke(Color.wikiSecondary.opacity(0.5), lineWidth: 1)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.wikiCard.opacity(0.5)))
                        .offset(x: 6, y: -6)
                }
            }
            .foregroundStyle(isSelected ? .wikiAccent : .wikiText)
        }
        .buttonStyle(.plain)
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
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack {
                            Text(tag)
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                            Text(Localized.trf("tag.tagPages", filteredPages.count))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: isEditMode ? "checklist" : "tag")
                        .font(.title)
                        .foregroundStyle(.wikiSecondary)
                    Text(isEditMode ? Localized.tr("tags.selectToManage") : Localized.tr("tagcloud.selectTag"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    // MARK: - 业务逻辑执行

    private func performRename() {
        guard let old = tagToRename, !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        store.renameTag(old, to: trimmed)
        if selectedTag == old { selectedTag = trimmed }
        tagToRename = nil
    }

    private func performDelete() {
        if let tag = tagToDelete {
            store.deleteTag(tag)
            if selectedTag == tag { selectedTag = nil }
        }
        tagToDelete = nil
    }

    private func performAddTag() {
        let trimmed = addTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // 创建一个存根页面来引入这个新标签
        _ = store.createPage(
            title: Localized.trf("tags.pageTitle", trimmed),
            type: .concept,
            content: Localized.trf("tags.pageContent", trimmed),
            tags: [trimmed]
        )
        
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

