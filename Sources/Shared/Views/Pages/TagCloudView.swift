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
    @State private var searchText = ""

    /// 从存储中心获取所有标签及其计数
    @State private var tags: [(tag: String, count: Int)] = []

    private func fetchData() async {
        let allTags = await store.getAllTags()
        await MainActor.run {
            self.tags = allTags
        }
    }

    /// 筛选后的标签列表
    var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    /// 根据选中的标签筛选页面
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
            .onChange(of: store.pages) { oldValue, newValue in
                Task { await fetchData() }
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // 操作栏：添加与管理按钮
            HStack(spacing: 20) {
                Spacer()
                if !isEditMode {
                    Button(action: { showAddTagDialog = true }) {
                        Label(Localized.tr("tags.addNew"), systemImage: "plus.circle")
                            .font(.footnote.weight(.medium))
                    }
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isEditMode.toggle()
                        if !isEditMode { selectedTagsForBulk.removeAll() }
                    }
                }) {
                    Label(isEditMode ? Localized.tr("misc.done") : Localized.tr("tags.manageTitle"), 
                          systemImage: isEditMode ? "checkmark.circle" : "checklist")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isEditMode ? .green : .wikiAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // 标签云展示区
            if tags.isEmpty {
                emptyTagsView
            } else {
                tagScrollView
                    .background(Color.wikiCard.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .overlay(alignment: .bottom) {
                        if isEditMode && !selectedTagsForBulk.isEmpty {
                            bulkActionBar
                        }
                    }
            }

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
            HapticManager.shared.trigger(.selection)
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
                    .stroke(isSelected ? Color.wikiAccent.opacity(0.4) : Color.wikiBorder.opacity(0.35), lineWidth: 0.5)
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
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isEditMode ? "checklist" : "tag")
                        .font(.system(size: 32))
                        .foregroundStyle(.wikiSecondary.opacity(0.5))
                    Text(isEditMode ? Localized.tr("tags.selectToManage") : Localized.tr("tagcloud.selectTag"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .frame(maxHeight: .infinity)
                .background(Color.wikiBackground.opacity(0.01)) // 响应点击
                .onTapGesture {
                    if isEditMode { isEditMode = false }
                }
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

