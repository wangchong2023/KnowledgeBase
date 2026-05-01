import SwiftUI

/// 页面详情视图
///
/// 显示知识库中单个页面的完整内容，支持查看和编辑两种模式。
///
/// ## 主要功能
/// - 显示页面标题、类型、图标、内容渲染
/// - 编辑页面内容和元数据（标题、标签、别名、类型、状态、可信度）
/// - 页面固定/取消固定操作
/// - 查看当前页面的反向链接列表
/// - 删除页面（带确认对话框）
///
/// ## 状态管理
/// - `isEditing`: 是否处于编辑模式
/// - `showBacklinks`: 是否显示反向链接面板
/// - `showIconPicker`: 是否显示图标选择器
///
/// ## 导航
/// - 支持通过 NavigationLink 跳转到其他页面
/// - 点击页面内容中的链接会导航到对应页面
struct PageDetailView: View {
    @State var page: WikiPage  ///< 当前展示的页面（@State 支持编辑修改）
    @EnvironmentObject var store: KMStore  ///< 全局知识库存储
    @State private var isEditing = false  ///< 是否处于编辑模式
    @State private var showBacklinks = false  ///< 是否显示反向链接面板
    @State private var showDeleteConfirmation = false  ///< 是否显示删除确认对话框
    @State private var showAliasEditor = false  ///< 是否显示别名编辑输入框
    @State private var newAlias = ""  ///< 新增别名输入框的内容
    @State private var showIconPicker = false  ///< 是否显示图标选择器
    
    var backlinks: [WikiPage] {
        store.backlinks(for: page.id)
    }  ///< 计算属性：获取所有引用当前页面的反向链接页面
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageDetailHeader(page: page)
                
                Divider()
                    .background(Color.wikiBorder)
                    .padding(.horizontal)
                
                // Content
                if isEditing {
                    MarkdownEditorView(page: $page, isEditing: $isEditing)
                } else if page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 空内容占位提示
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 32))
                            .foregroundStyle(.wikiSecondary)
                        Text(Localized.tr("page.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text(Localized.tr("page.emptyHint"))
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
                .accessibilityLabel(page.isPinned ? Localized.tr("page.unpin") : Localized.tr("page.pin"))
                
                Button(action: { showBacklinks.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("\(backlinks.count)")
                    }
                    .foregroundStyle(.wikiAccent)
                }
                .accessibilityLabel(Localized.tr("page.backlinks"))
                .accessibilityValue(Localized.trf("page.backlinksCount", backlinks.count))

                Button(action: {
                    if isEditing {
                        store.updatePage(page)
                    }
                    isEditing.toggle()
                }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .foregroundStyle(isEditing ? .green : .wikiAccent)
                }
                .accessibilityLabel(isEditing ? Localized.tr("page.doneEditing") : Localized.tr("page.edit"))
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
                        Label(Localized.tr("page.type"), systemImage: page.displayIcon)
                    }

                    // Page icon
                    Button(action: { showIconPicker = true }) {
                        HStack {
                            Image(systemName: page.displayIcon)
                            Text(Localized.tr("page.icon"))
                            if page.customIcon != nil {
                                Spacer()
                                Text(Localized.tr("editor.iconCustomized"))
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
                        Label(Localized.trf("page.statusFormat", page.status.displayName), systemImage: "flag.fill")
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
                        Label(Localized.trf("page.confidenceFormat", page.confidence.displayName), systemImage: "signal")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label(Localized.tr("page.deletePage"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .confirmationDialog(Localized.tr("page.confirmDelete"), isPresented: $showDeleteConfirmation) {
            Button(Localized.trf("page.deletePageTitle", page.title), role: .destructive) {
                store.deletePage(page)
            }
            Button(Localized.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("page.deleteMessage"))
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
    
    // MARK: - Backlinks Section
    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.wikiAccent)
                Text(Localized.tr("page.backlinks"))
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Text("(\(backlinks.count))")
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
            }
            
            if backlinks.isEmpty {
                Text(Localized.tr("page.noBackLinks"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(backlinks) { linkedPage in
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
                    .accessibilityLabel(Localized.trf("page.backlinkAccessibility", linkedPage.title, linkedPage.type.displayName))
                    .accessibilityHint(Localized.tr("page.doubleTapToNavigate"))
                }
            }
        }
        .padding()
    }
    
    // MARK: - Navigation

    /// 根据页面标题导航到对应页面
    /// - Parameter title: 目标页面的标题
    /// - Note: 如果找不到对应页面，则不进行导航
    private func navigateToPage(_ title: String) {
        if let target = store.pageByTitle(title) {
            store.selectedPageID = target.id
        }
    }
}
