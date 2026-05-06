// PageDetailView.swift
//
// 作者: Wang Chong
// 功能说明: 页面详情视图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
    @State private var viewModel: PageDetailViewModel
    var heroNamespace: Namespace.ID? = nil
    @Environment(KMStore.self) var store  ///< 全局知识库存储
    @Environment(AIWorkflowStore.self) var aiStore ///< AI 工作流存储
    @Environment(AppRouter.self) var router     ///< 路由管理器

    init(page: WikiPage, heroNamespace: Namespace.ID? = nil) {
        self.heroNamespace = heroNamespace
        self._viewModel = State(initialValue: PageDetailViewModel(page: page))
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            HStack(spacing: 8) {
                pinButton
                backlinksButton
                editButton
                aiMenuButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.wikiCard.opacity(0.5))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1))
        }
    }
    
    private var pinButton: some View {
        Button(action: { viewModel.togglePin() }) {
            Image(systemName: viewModel.page.isPinned ? "pin.fill" : "pin")
                .foregroundStyle(viewModel.page.isPinned ? .wikiComparison : .wikiSecondary)
        }
        .accessibilityLabel(viewModel.page.isPinned ? Localized.tr("page.unpin") : Localized.tr("page.pin"))
    }
    
    private var backlinksButton: some View {
        Button(action: { viewModel.showBacklinks.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text("\(viewModel.backlinks.count)")
            }
            .foregroundStyle(.wikiText)
        }
        .accessibilityLabel(Localized.tr("page.backlinks"))
        .accessibilityValue(Localized.trf("page.backlinksCount", viewModel.backlinks.count))
    }
    
    private var editButton: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            if viewModel.isEditing {
                store.updatePage(viewModel.page, forceDeepScan: false)
            }
            viewModel.isEditing.toggle()
        }) {
            Image(systemName: viewModel.isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                .foregroundStyle(viewModel.isEditing ? .green : .wikiText)
        }
        .accessibilityLabel(viewModel.isEditing ? Localized.tr("page.doneEditing") : Localized.tr("page.edit"))
    }
    
    private var aiMenuButton: some View {
        Menu {
            Button(action: { aiStore.runPageAISummary(content: viewModel.page.content) }) {
                Label(Localized.tr("page.ai.summary"), systemImage: "wand.and.stars")
            }
            Button(action: { aiStore.extractPageActions(content: viewModel.page.content) }) {
                Label(Localized.tr("page.ai.extractActions"), systemImage: "checkmark.seal")
            }

            Menu {
                Button(action: { aiStore.performPageSynthesis(type: .mindmap, title: viewModel.page.title, content: viewModel.page.content) }) {
                    Label(Localized.tr("page.ai.mindmap"), systemImage: "rectangle.stack.badge.person.crop")
                }
                Button(action: { aiStore.performPageSynthesis(type: .quiz, title: viewModel.page.title, content: viewModel.page.content) }) {
                    Label(Localized.tr("page.ai.quiz"), systemImage: "questionmark.circle")
                }
                Button(action: { aiStore.performPageSynthesis(type: .slides, title: viewModel.page.title, content: viewModel.page.content) }) {
                    Label(Localized.tr("page.ai.slides"), systemImage: "play.rectangle")
                }
                Button(action: { aiStore.performPageSynthesis(type: .report, title: viewModel.page.title, content: viewModel.page.content) }) {
                    Label(Localized.tr("page.ai.report"), systemImage: "doc.text.magnifyingglass")
                }
                Button(action: { aiStore.performPageSynthesis(type: .infographic, title: viewModel.page.title, content: viewModel.page.content) }) {
                    Label(Localized.tr("page.ai.infographic"), systemImage: "chart.bar.doc.horizontal")
                }
            } label: {
                Label(Localized.tr("page.ai.lab"), systemImage: "flask")
            }
            
            Divider()
            Button(action: { viewModel.showSnapshotHistory = true }) {
                Label(Localized.tr("page.history"), systemImage: "clock.arrow.circlepath")
            }
            Button(action: { expandStub() }) {
                Label(Localized.tr("page.expandStub"), systemImage: "text.badge.plus")
            }
            Button(action: { findRelatedLinks() }) {
                Label(Localized.tr("page.findLinks"), systemImage: "link.badge.plus")
            }
        } label: {
            Image(systemName: "sparkles.circle.fill")
                .foregroundStyle(.wikiAccent)
        }
        .disabled(viewModel.isEditing)
    }
    
    private var moreMenu: some View {
        Menu {
            typeSubmenu
            iconMenuItem
            statusSubmenu
            confidenceSubmenu
            Divider()
            
            // 导出当前页面为 Markdown 文件 (支持 AirDrop, 微信, 邮件等)
            if let fileURL = store.exportPageAsMarkdown(viewModel.page) {
                ShareLink(item: fileURL, preview: SharePreview(viewModel.page.title, image: Image(systemName: "doc.text"))) {
                    Label(L10n.Transfer.tr("export.header"), systemImage: "square.and.arrow.up")
                }
            }
            Button(action: { store.copyPageToClipboard(viewModel.page); HapticFeedback.shared.trigger(.success) }) {
                Label(L10n.Common.tr("copy"), systemImage: "doc.on.doc")
            }
            
            Divider()
            deleteButton
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.wikiSecondary)
        }
    }
    
    private var typeSubmenu: some View {
        Menu {
            ForEach(PageType.allCases) { type in
                Button(action: { viewModel.updateType(type) }) {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            Label(Localized.tr("page.type"), systemImage: viewModel.page.displayIcon)
        }
    }
    
    private var iconMenuItem: some View {
        Button(action: { viewModel.showIconPicker = true }) {
            HStack {
                Image(systemName: viewModel.page.displayIcon)
                Text(Localized.tr("page.icon"))
                if viewModel.page.customIcon != nil {
                    Spacer()
                    Text(L10n.Editor.tr("iconCustomized"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var statusSubmenu: some View {
        Menu {
            ForEach(PageStatus.allCases, id: \.self) { status in
                Button(action: { viewModel.updateStatus(status) }) {
                    Label(status.displayName, systemImage: "circle.fill")
                        .foregroundStyle(status.color)
                }
            }
        } label: {
            Label(Localized.trf("page.statusFormat", viewModel.page.status.displayName), systemImage: "flag.fill")
        }
    }
    
    private var confidenceSubmenu: some View {
        Menu {
            ForEach(Confidence.allCases, id: \.self) { conf in
                Button(action: { viewModel.updateConfidence(conf) }) {
                    Label(conf.displayName, systemImage: "signal")
                }
            }
        } label: {
            Label(Localized.trf("page.confidenceFormat", viewModel.page.confidence.displayName), systemImage: "signal")
        }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive, action: { viewModel.showDeleteConfirmation = true }) {
            Label(Localized.tr("page.deletePage"), systemImage: "trash")
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Immersive Background
            LinearGradient(
                colors: [viewModel.page.type.themedColor.opacity(0.08), Color.wikiBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Content
                    Group {
                        if viewModel.isEditing {
                            MarkdownEditorView(page: $viewModel.page, isEditing: $viewModel.isEditing)
                                .padding(.top, 20)
                        } else if viewModel.page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // 空内容占位提示
                            emptyStateView
                        } else {
                            MarkdownRendererView(content: viewModel.page.content, isPrivate: viewModel.page.isPrivate, onLinkTap: { title in
                                navigateToPage(title)
                            })
                            .padding(.vertical)
                        }

                        Divider()
                            .background(Color.wikiBorder)

                        provenanceSection

                        semanticRecommendationsSection
                        
                        aiResultDisplaySection

                        Divider()
                            .background(Color.wikiBorder)

                        backlinksSection
                    }
                    .padding(.horizontal)
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: 800) // 限制 iPad/Mac 上的最大阅读宽度，提升易读性
        .frame(maxWidth: .infinity) // 居中显示
        .background(Color.wikiBackground)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar { toolbarContent }
        .confirmationDialog(Localized.tr("page.confirmDelete"), isPresented: $viewModel.showDeleteConfirmation) {
            Button(Localized.trf("page.deletePageTitle", viewModel.page.title), role: .destructive) {
                viewModel.deletePage()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("page.deleteMessage"))
        }
        .sheet(isPresented: $viewModel.showBacklinks) {
            BacklinksView(page: viewModel.page)
        }
        .sheet(isPresented: $viewModel.showIconPicker) {
            NavigationStack {
                IconPickerView(selectedIcon: Binding(
                    get: { viewModel.page.customIcon },
                    set: { newIcon in
                        var updated = viewModel.page
                        updated.customIcon = newIcon
                        store.updatePage(updated, forceDeepScan: false)
                        viewModel.page = updated
                    }
                ))
            }
        }
        .onChange(of: viewModel.page) { _, newValue in
            if !viewModel.isEditing {
                store.updatePage(newValue, forceDeepScan: false)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // 空间导航面包屑
                if !router.navigationHistory.isEmpty {
                    BreadcrumbView(history: router.navigationHistory) { id in
                        if let target = store.pages.first(where: { $0.id == id }) {
                            navigateToPage(target.title)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                PageDetailHeader(page: viewModel.page, heroNamespace: heroNamespace)
                    .padding(.top, router.navigationHistory.isEmpty ? 10 : 0)
                    .background(.ultraThinMaterial)
            }
            .frame(maxWidth: 800)
            .overlay(
                Divider().background(Color.wikiBorder),
                alignment: .bottom
            )
        }
        .sheet(isPresented: $viewModel.showSnapshotHistory) {
            PageHistoryView(page: viewModel.page)
        }
        .onAppear {
            router.addToHistory(viewModel.page)
        }
        .onChange(of: viewModel.page) { _, newValue in
            router.addToHistory(newValue)
        }
        .quizPresentation(activeQuiz: Binding(get: { aiStore.activeQuiz }, set: { aiStore.activeQuiz = $0 }))
    }
    
    // MARK: - AI Result Display Section
    @ViewBuilder
    private var aiResultDisplaySection: some View {
        if aiStore.isProcessingPageAI || aiStore.activePageAIResult != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.wikiAccent)
                    Text(Localized.tr("page.ai.labOutput"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Spacer()
                    if !aiStore.isProcessingPageAI {
                        if let result = aiStore.activePageAIResult, result.contains("- ") {
                            Button(action: {
                                Task {
                                    @Inject var workflowService: WorkflowService
                                    try? await workflowService.syncToReminders(text: result, title: viewModel.page.title)
                                }
                            }) {
                                Label(L10n.Common.tr("syncToReminders"), systemImage: "checklist")
                                    .font(.caption)
                                    .foregroundStyle(.wikiAccent)
                            }
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: { 
                            WikiPasteboard.string = aiStore.activePageAIResult
                            HapticFeedback.shared.trigger(.success)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        
                        Button(action: { aiStore.activePageAIResult = nil }) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                }
                
                if aiStore.isProcessingPageAI {
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBox(width: 200, height: 20)
                        SkeletonBox(height: 120)
                        SkeletonBox(height: 60)
                    }
                } else if let result = aiStore.activePageAIResult {
                    MarkdownRendererView(content: result, isPrivate: false, onLinkTap: { text in
                        navigateToPage(text)
                    })
                    .padding(12)
                    .background(Color.wikiAccent.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.wikiAccent.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Subviews
    private var emptyStateView: some View {
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
    }
    
    // MARK: - Provenance Section
    private var provenanceSection: some View {
        Group {
            if let sourceURL = viewModel.page.sourceURL, let url = URL(string: sourceURL) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundStyle(.wikiAccent)
                        Text(Localized.tr("page.source.title"))
                            .font(.headline)
                            .foregroundStyle(.wikiText)
                        Spacer()
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(Localized.tr("page.source.open"))
                                Image(systemName: "arrow.up.right.circle")
                            }
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sourceURL)
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if let snippet = viewModel.page.rawTextSnippet, !snippet.isEmpty {
                            Text(snippet)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.wikiSecondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.wikiBackground)
                                .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                                .lineLimit(3)
                        }
                    }
                    .padding(10)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                }
                .padding()
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Related Pages Section (Supports Reordering)
    private var relatedPagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundStyle(.wikiAccent)
                Text(Localized.tr("page.related.manual"))
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                
                Spacer()
                
                if viewModel.isEditing {
                    Text(L10n.Common.tr("dragToSort"))
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }
            }
            
            let relatedPages = viewModel.page.relatedPageIDs.compactMap { id in
                store.pages.first(where: { $0.id == id })
            }
            
            if relatedPages.isEmpty {
                Text(Localized.tr("page.related.none"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary.opacity(0.6))
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(relatedPages) { related in
                        HStack {
                            Image(systemName: related.displayIcon)
                                .foregroundStyle(related.type.themedColor)
                            Text(related.title)
                                .font(.subheadline)
                            Spacer()
                            if viewModel.isEditing {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.wikiBorder)
                            }
                        }
                        .padding(10)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onDrag {
                            return NSItemProvider(object: related.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: RelatedPageDropDelegate(item: related, page: $viewModel.page))
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - AI Contextual Sparks (Predictive Context)
    private var semanticRecommendationsSection: some View {
        let recommendations = aiStore.findSimilarPages(for: viewModel.page)
        
        return Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.wikiAccent.opacity(0.1))
                                .frame(width: 24, height: 24)
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundStyle(.wikiAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Localized.tr("page.aiInsights"))
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Text(Localized.tr("page.aiInsights.desc"))
                                .font(.system(size: 9))
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .padding(.bottom, 4)
                    
                    VStack(spacing: 10) {
                        ForEach(recommendations) { recPage in
                            recommendationRow(for: recPage)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.wikiAccent.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [.wikiAccent.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Recommendation Row
    private func recommendationRow(for recPage: WikiPage) -> some View {
        NavigationLink(value: AppRoute.pageDetail(id: recPage.id)) {
            HStack {
                Image(systemName: recPage.displayIcon)
                    .foregroundStyle(recPage.type.themedColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recPage.title)
                        .font(.subheadline.weight(.medium))
                    let summaryText = String(recPage.content.prefix(60)) + "..."
                    Text(summaryText)
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding(12)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(LinearGradient(colors: [.wikiAccent.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                Text("(\(viewModel.backlinks.count)")
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
            }
            
            if viewModel.backlinks.isEmpty {
                Text(Localized.tr("page.noBackLinks"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.backlinks) { linkedPage in
                    NavigationLink(value: AppRoute.pageDetail(id: linkedPage.id)) {
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
    
    private func expandStub() {
        // Implementation logic: Ask LLM to fill missing details based on context
    }

    private func findRelatedLinks() {
        // Implementation logic: Trigger a partial AI Link Scan for this page
        Task { await aiStore.runAIScan() }
    }

    /// 根据页面标题导航到对应页面
    private func navigateToPage(_ title: String) {
        if let target = store.pages.first(where: { $0.title == title }) {
            router.navigate(to: .pageDetail(id: target.id))
        }
    }
}

// MARK: - Drop Delegate for Reordering
struct RelatedPageDropDelegate: DropDelegate {
    let item: WikiPage
    @Binding var page: WikiPage

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let fromItem = info.itemProviders(for: [.text]).first else { return }
        
        fromItem.loadObject(ofClass: NSString.self) { (uuidString, error) in
            guard let uuidString = uuidString as? String,
                  let fromID = UUID(uuidString: uuidString),
                  fromID != item.id else { return }
            
            DispatchQueue.main.async {
                let fromIndex = page.relatedPageIDs.firstIndex(of: fromID)
                let toIndex = page.relatedPageIDs.firstIndex(of: item.id)
                
                if let from = fromIndex, let to = toIndex {
                    withAnimation {
                        page.relatedPageIDs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                    }
                }
            }
        }
    }
}
// MARK: - Snapshot History View
struct SnapshotHistoryView: View {
    let page: WikiPage
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var history: [SnapshotInfo] = []
    @State private var selectedSnapshot: SnapshotInfo?
    @State private var compareContent: String?
    
    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    Text(Localized.tr("page.history.none"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { snapshot in
                        Button(action: {
                            selectedSnapshot = snapshot
                            compareContent = store.snapshotService.rollback(to: snapshot)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.medium))
                                    Text(Localized.tr("page.history.physical"))
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.wikiBorder)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(Localized.tr("page.history"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("close")) { dismiss() }
                }
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                SnapshotDetailView(page: page, snapshot: snapshot, content: compareContent ?? "", onRollback: {
                    var rolledBack = page
                    rolledBack.content = compareContent ?? ""
                    store.updatePage(rolledBack, forceDeepScan: false)
                    dismiss()
                })
            }
        }
        .onAppear {
            history = store.snapshotService.getHistory(for: page.id)
        }
    }
}

private struct SnapshotDetailView: View {
    let page: WikiPage
    let snapshot: SnapshotInfo
    let content: String
    let onRollback: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label(Localized.tr("page.history.version"), systemImage: "clock")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                            Text(snapshot.date.formatted())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                        
                        MarkdownRendererView(content: content, isPrivate: page.isPrivate, onLinkTap: { _ in })
                    }
                    .padding()
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text(L10n.Common.tr("cancel"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.wikiCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onRollback) {
                        Text(Localized.tr("page.history.rollback"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.wikiAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle(Localized.tr("page.snapshot.preview"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background(Color.wikiBackground)
        }
    }
}


