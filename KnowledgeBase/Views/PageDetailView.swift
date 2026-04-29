import SwiftUI

struct PageDetailView: View {
    @State var page: WikiPage
    @EnvironmentObject var store: KMStore
    @State private var isEditing = false
    @State private var showBacklinks = false
    @State private var showDeleteConfirmation = false
    @State private var showAliasEditor = false
    @State private var newAlias = ""
    @State private var showIconPicker = false
    
    var backlinks: [WikiPage] {
        store.backlinks(for: page.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                pageHeader
                
                Divider()
                    .background(Color.wikiBorder)
                
                // Content
                if isEditing {
                    MarkdownEditorView(page: $page, isEditing: $isEditing)
                } else if page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 空内容占位提示
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 32))
                            .foregroundStyle(.wikiSecondary)
                        Text("这个页面还没有内容")
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text("点击右上角 ✏️ 开始编辑，使用 [[页面名]] 建立关联")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.wikiAccent.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else {
                    MarkdownRendererView(content: page.content, onLinkTap: { title in
                        navigateToPage(title)
                    })
                    .padding()
                }
                
                Divider()
                    .background(Color.wikiBorder)
                    .padding(.horizontal)
                
                // Backlinks section
                backlinksSection
            }
        }
        .background(Color.wikiBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Register navigationDestination so NavigationLink(value: WikiPage) works
        // both in the Graph tab's NavigationStack and elsewhere.
        .navigationDestination(for: WikiPage.self) { destination in
            PageDetailView(page: destination)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Pin/Unpin button
                Button(action: {
                    page.isPinned.toggle()
                    store.updatePage(page)
                }) {
                    Image(systemName: page.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(page.isPinned ? .wikiComparison : .wikiSecondary)
                }
                .accessibilityLabel(page.isPinned ? "取消固定" : "固定页面")
                
                Button(action: { showBacklinks.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("\(backlinks.count)")
                    }
                    .foregroundStyle(.wikiAccent)
                }
                .accessibilityLabel("反向链接")
                .accessibilityValue("\(backlinks.count) 个页面")

                Button(action: {
                    if isEditing {
                        store.updatePage(page)
                    }
                    isEditing.toggle()
                }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .foregroundStyle(isEditing ? .green : .wikiAccent)
                }
                .accessibilityLabel(isEditing ? "完成编辑" : "编辑页面")
            }
            
            ToolbarItemGroup(placement: .topBarLeading) {
                Menu {
                    // Page type
                    Menu {
                        ForEach(PageType.allCases) { type in
                            Button(action: {
                                page.type = type
                                store.updatePage(page)
                            }) {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    } label: {
                        Label("页面类型", systemImage: page.displayIcon)
                    }

                    // Page icon
                    Button(action: { showIconPicker = true }) {
                        HStack {
                            Image(systemName: page.displayIcon)
                            Text("页面图标")
                            if page.customIcon != nil {
                                Spacer()
                                Text("已自定义")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Page status
                    Menu {
                        ForEach(PageStatus.allCases, id: \.self) { status in
                            Button(action: {
                                page.status = status
                                store.updatePage(page)
                            }) {
                                Label(status.displayName, systemImage: "circle.fill")
                                    .foregroundStyle(status.color)
                            }
                        }
                    } label: {
                        Label("状态: \(page.status.displayName)", systemImage: "flag.fill")
                    }
                    
                    // Confidence
                    Menu {
                        ForEach(Confidence.allCases, id: \.self) { conf in
                            Button(action: {
                                page.confidence = conf
                                store.updatePage(page)
                            }) {
                                Label(conf.displayName, systemImage: "signal")
                            }
                        }
                    } label: {
                        Label("可信度: \(page.confidence.displayName)", systemImage: "signal")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label("删除页面", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirmation) {
            Button("删除「\(page.title)」", role: .destructive) {
                store.deletePage(page)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可恢复，页面及所有引用将被删除。")
        }
        .sheet(isPresented: $showBacklinks) {
            BacklinksView(page: page)
        }
        .sheet(isPresented: $showIconPicker) {
            NavigationStack {
                IconPickerView(selectedIcon: Binding(
                    get: { page.customIcon },
                    set: { newIcon in
                        page.customIcon = newIcon
                        store.updatePage(page)
                    }
                ))
            }
        }
        .onChange(of: page) { _, newValue in
            if !isEditing {
                store.updatePage(newValue)
            }
        }
    }
    
    // MARK: - Page Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Breadcrumb: type path
            HStack(spacing: 4) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
                Text("Wiki")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.wikiSecondary)
                Text(page.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(page.type.themedColor)
                if page.isPinned {
                    Spacer()
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.wikiComparison)
                }
            }
            
            HStack(spacing: 10) {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: page.displayIcon)
                        .font(.caption)
                    Text(page.type.displayName)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(page.type.themedColor.opacity(0.2))
                .clipShape(Capsule())
                .foregroundStyle(page.type.themedColor)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("页面类型: \(page.type.displayName)")

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(page.status.color)
                        .frame(width: 6, height: 6)
                    Text(page.status.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(page.status.color.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(page.status.color)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("状态: \(page.status.displayName)")

                // Confidence
                HStack(spacing: 4) {
                    Image(systemName: "signal")
                        .font(.caption2)
                    Text(page.confidence.displayName)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(page.confidence.color.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(page.confidence.color)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("可信度: \(page.confidence.displayName)")
                
                Spacer()
            }
            
            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("页面标题: \(page.title)")
            
            // Aliases
            if !page.aliases.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.branch")
                            .font(.caption2)
                            .foregroundStyle(.wikiSource)
                        ForEach(page.aliases, id: \.self) { alias in
                            Text(alias)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.wikiSource.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiSource)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("别名: \(page.aliases.joined(separator: "，"))")
                }
            }

            // Tags
            if !page.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(page.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.wikiAccent.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.wikiAccent)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("标签: \(page.tags.map { "#\($0)" }.joined(separator: "，"))")
                }
            }
            
            // Meta info
            HStack(spacing: 16) {
                Label("创建: \(page.created.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label("更新: \(page.updated.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock")
                Label("\(page.wordCount) 字", systemImage: "textformat")
                Label("\(page.outgoingLinks.count) 出链", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.wikiSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("元信息，创建于 \(page.created.formatted(date: .abbreviated, time: .omitted))，\(page.wordCount) 字，\(page.outgoingLinks.count) 个出站链接")
        }
        .padding()
    }
    
    // MARK: - Backlinks Section
    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.wikiAccent)
                Text("反向链接")
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Text("(\(backlinks.count))")
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
            }
            
            if backlinks.isEmpty {
                Text("暂无反向链接")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(backlinks) { linkedPage in
                    // NavigationLink(value:) works in any NavigationStack/NavigationSplitView
                    // — the nearest ancestor picks it up. In Graph tab it pushes a new
                    // PageDetailView; in Wiki tab the SplitView updates the detail column.
                    NavigationLink(value: linkedPage) {
                        HStack(spacing: 10) {
                            Image(systemName: linkedPage.displayIcon)
                                .foregroundStyle(linkedPage.type.themedColor)
                                .frame(width: 28, height: 28)
                                .background(linkedPage.type.themedColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))

                            Text(linkedPage.title)
                                .font(.subheadline)
                                .foregroundStyle(.wikiText)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("反向链接: \(linkedPage.title)，类型: \(linkedPage.type.displayName)")
                    .accessibilityHint("双击跳转到该页面")
                }
            }
        }
        .padding()
    }
    
    // MARK: - Navigation
    private func navigateToPage(_ title: String) {
        if let target = store.pageByTitle(title) {
            // In Wiki SplitView: update selectedPageID to switch detail column.
            // In Graph NavigationStack: the NavigationLink(value:) + navigationDestination
            // registered above will handle push navigation when content links are tapped.
            store.selectedPageID = target.id
        }
    }
}
