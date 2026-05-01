// MARK: - 标签云视图 (导航容器)
struct TagCloudView: View {
    var body: some View {
        NavigationStack {
            TagCloudViewContent()
        }
    }
}

// MARK: - 标签管理主内容
struct TagCloudViewContent: View {
    @EnvironmentObject var store: KMStore
    @State private var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var showDeleteConfirm = false
    @State private var tagToDelete: String?
    @State private var showAddTagDialog = false
    @State private var addTagName = ""
    
    // 批量管理状态
    @State private var isEditMode = false
    @State private var selectedTagsForBulk = Set<String>()
    @State private var showBulkDeleteConfirm = false

    /// 从存储中心获取所有标签及其计数
    var tags: [(tag: String, count: Int)] {
        store.allTags
    }

    /// 根据选中的标签筛选页面
    var filteredPages: [WikiPage] {
        guard let tag = selectedTag else { return store.pages }
        return store.pages.filter { $0.tags.contains(tag) }
    }

    var body: some View {
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
        .background(Color.wikiBackground)
        .navigationTitle(isEditMode ? "管理标签" : Localized.tr("tag.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    // 编辑模式开关
                    Button(isEditMode ? "完成" : "批量管理") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode { selectedTagsForBulk.removeAll() }
                        }
                    }
                    .font(.subheadline)
                    
                    if !isEditMode {
                        Button(action: { showAddTagDialog = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
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
            let count = tags.first { $0.tag == tagToDelete }?.count ?? 0
            Text(Localized.trf("tag.deleteMessage", count, tagToDelete ?? ""))
        }
        // 新增标签对话框
        .alert("新增标签", isPresented: $showAddTagDialog) {
            TextField("输入标签名称", text: $addTagName)
            Button(Localized.tr("misc.cancel"), role: .cancel) { addTagName = "" }
            Button("创建") {
                performAddTag()
            }
        } message: {
            Text("创建一个新标签，系统将自动为此标签生成一个占位页面。")
        }
        // 批量删除确认
        .alert("确认批量删除", isPresented: $showBulkDeleteConfirm) {
            Button(Localized.tr("misc.cancel"), role: .cancel) { }
            Button("全部删除", role: .destructive) {
                store.deleteTags(selectedTagsForBulk)
                selectedTagsForBulk.removeAll()
                isEditMode = false
            }
        } message: {
            Text("确定要删除选中的 \(selectedTagsForBulk.count) 个标签吗？这将从所有关联页面中移除它们。")
        }
    }

    // MARK: - 子视图组件

    private var bulkActionBar: some View {
        HStack {
            Text("已选中 \(selectedTagsForBulk.count) 个标签")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Spacer()
            Button(role: .destructive, action: { showBulkDeleteConfirm = true }) {
                Text("批量删除")
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
                if isEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .wikiAccent : .wikiSecondary)
                }
                Text("#\(item.tag)")
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                Text("\(item.count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.wikiAccent.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.wikiAccent.opacity(0.15) : Color.wikiCard)
            .overlay(
                RoundedRectangle(cornerRadius: Capsule().path(in: .zero).boundingRect.height) // This is just for demonstration, Capsule has no easy border
                    .stroke(isSelected ? Color.wikiAccent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .clipShape(Capsule())
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
                            Text(Localized.trf("tag.tagPages", tag))
                                .foregroundStyle(.wikiText)
                            Spacer()
                            Text(Localized.trf("page.backlinksCount", filteredPages.count))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: isEditMode ? "checklist" : "tag")
                        .font(.title)
                        .foregroundStyle(.wikiSecondary)
                    Text(isEditMode ? "请选择要管理的标签" : Localized.tr("tagcloud.selectTag"))
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
            title: "关于 #\(trimmed)",
            type: .concept,
            content: "这是一个自动创建的页面，用于保存标签 #\(trimmed)。",
            tags: [trimmed]
        )
        
        addTagName = ""
        showAddTagDialog = false
        selectedTag = trimmed
    }
}

// 简单的模糊背景视图
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

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}
