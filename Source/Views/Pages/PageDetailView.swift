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
    @State var page: WikiPage
    var heroNamespace: Namespace.ID? = nil
    @EnvironmentObject var store: KMStore  ///< 全局知识库存储
    @State private var isEditing = false  ///< 是否处于编辑模式
    @State private var showBacklinks = false  ///< 是否显示反向链接面板
    @State private var showDeleteConfirmation = false  ///< 是否显示删除确认对话框
    @State private var showAliasEditor = false  ///< 是否显示别名编辑输入框
    @State private var newAlias = ""  ///< 新增别名输入框的内容
    @State private var showIconPicker = false  ///< 是否显示图标选择器
    @State private var showSnapshotHistory = false ///< 是否显示快照历史
    @State private var isLoadingAI = false ///< AI 加载状态
    @State private var aiResult: String? ///< AI 结果展示
    @State private var activeQuiz: QuizModel? = nil ///< 当前活跃的测验模型
    
    var backlinks: [WikiPage] {
        store.pages.filter { $0.outgoingLinks.contains(page.title) }
    }  ///< 计算属性：获取所有引用当前页面的反向链接页面
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
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
        Button(action: {
            page.isPinned.toggle()
            store.updatePage(page, forceDeepScan: false)
        }) {
            Image(systemName: page.isPinned ? "pin.fill" : "pin")
                .foregroundStyle(page.isPinned ? .wikiComparison : .wikiSecondary)
        }
        .accessibilityLabel(page.isPinned ? Localized.tr("page.unpin") : Localized.tr("page.pin"))
    }
    
    private var backlinksButton: some View {
        Button(action: { showBacklinks.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text("\(backlinks.count)")
            }
            .foregroundStyle(.wikiText)
        }
        .accessibilityLabel(Localized.tr("page.backlinks"))
        .accessibilityValue(Localized.trf("page.backlinksCount", backlinks.count))
    }
    
    private var editButton: some View {
        Button(action: {
            if isEditing {
                store.updatePage(page, forceDeepScan: false)
            }
            isEditing.toggle()
        }) {
            Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                .foregroundStyle(isEditing ? .green : .wikiText)
        }
        .accessibilityLabel(isEditing ? Localized.tr("page.doneEditing") : Localized.tr("page.edit"))
    }
    
    private var aiMenuButton: some View {
        Menu {
            Button(action: { runAISummary() }) {
                Label(Localized.tr("page.ai.summary"), systemImage: "wand.and.stars")
            }
            Button(action: { extractActions() }) {
                Label(Localized.tr("page.ai.extractActions"), systemImage: "checkmark.seal")
            }
            
            Menu {
                Button(action: { synthesize(.mindmap) }) {
                    Label(Localized.tr("page.ai.mindmap"), systemImage: "rectangle.stack.badge.person.crop")
                }
                Button(action: { synthesize(.quiz) }) {
                    Label(Localized.tr("page.ai.quiz"), systemImage: "questionmark.circle")
                }
                Button(action: { synthesize(.slides) }) {
                    Label(Localized.tr("page.ai.slides"), systemImage: "play.rectangle")
                }
                Button(action: { synthesize(.report) }) {
                    Label(Localized.tr("page.ai.report"), systemImage: "doc.text.magnifyingglass")
                }
            } label: {
                Label(Localized.tr("page.ai.lab"), systemImage: "flask")
            }
            
            Divider()
            Button(action: { showSnapshotHistory = true }) {
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
        .disabled(isEditing)
    }
    
    private var moreMenu: some View {
        Menu {
            typeSubmenu
            iconMenuItem
            statusSubmenu
            confidenceSubmenu
            Divider()
            
            // 导出当前页面为 Markdown 文件 (支持 AirDrop, 微信, 邮件等)
            if let fileURL = exportMarkdownFile() {
                ShareLink(item: fileURL, preview: SharePreview(page.title, image: Image(systemName: "doc.text"))) {
                    Label(Localized.tr("export.header"), systemImage: "square.and.arrow.up")
                }
            }
            Button(action: { copyToClipboard() }) {
                Label(Localized.tr("misc.copy"), systemImage: "doc.on.doc")
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
                Button(action: {
                    page.type = type
                    store.updatePage(page, forceDeepScan: false)
                }) {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            Label(Localized.tr("page.type"), systemImage: page.displayIcon)
        }
    }
    
    private var iconMenuItem: some View {
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
    }
    
    private var statusSubmenu: some View {
        Menu {
            ForEach(PageStatus.allCases, id: \.self) { status in
                Button(action: {
                    page.status = status
                    store.updatePage(page, forceDeepScan: false)
                }) {
                    Label(status.displayName, systemImage: "circle.fill")
                        .foregroundStyle(status.color)
                }
            }
        } label: {
            Label(Localized.trf("page.statusFormat", page.status.displayName), systemImage: "flag.fill")
        }
    }
    
    private var confidenceSubmenu: some View {
        Menu {
            ForEach(Confidence.allCases, id: \.self) { conf in
                Button(action: {
                    page.confidence = conf
                    store.updatePage(page, forceDeepScan: false)
                }) {
                    Label(conf.displayName, systemImage: "signal")
                }
            }
        } label: {
            Label(Localized.trf("page.confidenceFormat", page.confidence.displayName), systemImage: "signal")
        }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive, action: { showDeleteConfirmation = true }) {
            Label(Localized.tr("page.deletePage"), systemImage: "trash")
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Immersive Background
            LinearGradient(
                colors: [page.type.themedColor.opacity(0.08), Color.wikiBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Content
                    Group {
                        if isEditing {
                            MarkdownEditorView(page: $page, isEditing: $isEditing)
                                .padding(.top, 20)
                        } else if page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // 空内容占位提示
                            emptyStateView
                        } else {
                            MarkdownRendererView(content: page.content, onLinkTap: { title in
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
        .navigationBarTitleDisplayMode(.inline)
        // Register navigationDestination so NavigationLink(value: WikiPage) works
        // both in the Graph tab's NavigationStack and elsewhere.
        .navigationDestination(for: WikiPage.self) { destination in
            PageDetailView(page: destination, heroNamespace: heroNamespace)
        }
        .toolbar { toolbarContent }
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
                        store.updatePage(page, forceDeepScan: false)
                    }
                ))
            }
        }
        .onChange(of: page) { _, newValue in
            if !isEditing {
                store.updatePage(newValue, forceDeepScan: false)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                // 空间导航面包屑
                if !store.navigationHistory.isEmpty {
                    BreadcrumbView(history: store.navigationHistory) { id in
                        if let target = store.pages.first(where: { $0.id == id }) {
                            navigateToPage(target.title)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                PageDetailHeader(page: page, heroNamespace: heroNamespace)
                    .padding(.top, store.navigationHistory.isEmpty ? 10 : 0)
                    .background(.ultraThinMaterial)
            }
            .frame(maxWidth: 800)
            .overlay(
                Divider().background(Color.wikiBorder),
                alignment: .bottom
            )
        }
        .sheet(isPresented: $showSnapshotHistory) {
            SnapshotHistoryView(page: page)
        }
        .quizPresentation(activeQuiz: $activeQuiz)
        .overlay {
            if isLoadingAI && aiResult == nil {
                ZStack {
                    Color.black.opacity(0.001) // 极低透明度捕获触摸，防止点击底层
                        .ignoresSafeArea()
                        .onTapGesture { /* 拦截点击 */ }
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text(Localized.tr("misc.aiThinking"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .background(.ultraThinMaterial.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 20)
                }
            }
        }
    }
    
    // MARK: - AI Result Display Section
    @ViewBuilder
    private var aiResultDisplaySection: some View {
        if isLoadingAI || aiResult != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.wikiAccent)
                    Text(Localized.tr("page.ai.labOutput"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Spacer()
                    if !isLoadingAI {
                        Button(action: { 
                            WikiPasteboard.string = aiResult
                            HapticManager.shared.trigger(.success)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        
                        Button(action: { aiResult = nil }) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                }
                
                if isLoadingAI {
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonBox(width: 200, height: 20)
                        SkeletonBox(height: 120)
                        SkeletonBox(height: 60)
                    }
                } else if let result = aiResult {
                    MarkdownRendererView(content: result, onLinkTap: { text in
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
            if let sourceURL = page.sourceURL, let url = URL(string: sourceURL) {
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
                        
                        if let snippet = page.rawTextSnippet, !snippet.isEmpty {
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
                
                if isEditing {
                    Text(Localized.tr("misc.dragToSort"))
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }
            }
            
            let relatedPages = page.relatedPageIDs.compactMap { id in
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
                            if isEditing {
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
                        .onDrop(of: [.text], delegate: RelatedPageDropDelegate(item: related, page: $page))
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - AI Contextual Sparks (Predictive Context)
    private var semanticRecommendationsSection: some View {
        let recommendations = store.findSimilarPages(for: page)
        
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
        NavigationLink(value: recPage) {
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
    
    // MARK: - AI Actions Implementation
    
    private func runAISummary() {
        Task {
            isLoadingAI = true
            defer { isLoadingAI = false }
            do {
                let summary = try await store.llmService.summarize(content: page.content)
                aiResult = summary
            } catch {
                print("AI Summary failed: \(error)")
            }
        }
    }
    
    private func extractActions() {
        Task {
            isLoadingAI = true
            defer { isLoadingAI = false }
            do {
                let actions = try await store.llmService.extractActions(content: page.content)
                aiResult = actions
            } catch {
                print("AI Actions failed: \(error)")
            }
        }
    }
    
    enum SynthesisType {
        case mindmap, quiz, slides, report
    }
    
    private func synthesize(_ type: SynthesisType) {
        let title: String
        switch type {
        case .mindmap: title = "生成思维导图"
        case .quiz: title = "生成知识测验"
        case .slides: title = "生成演示大纲"
        case .report: title = "生成深度总结"
        }
        
        let taskID = TaskCenter.shared.addTask(type: .ai, name: title, target: page.title)
        
        Task {
            isLoadingAI = true
            defer { isLoadingAI = false }
            do {
                let result: String
                switch type {
                case .mindmap: result = try await store.llmService.generateMindMap(content: page.content)
                case .quiz: result = try await store.llmService.generateQuiz(content: page.content)
                case .slides: result = try await store.llmService.generatePresentation(content: page.content)
                case .report: result = try await store.llmService.generateReport(content: page.content)
                }
                
                TaskCenter.shared.updateTask(taskID, status: .completed)
                
                if type == .quiz {
                    // 尝试解析 JSON
                    if let data = result.data(using: .utf8),
                       let quiz = try? JSONDecoder().decode(QuizModel.self, from: data) {
                        activeQuiz = quiz
                    } else {
                        aiResult = result // 解析失败则降级显示文本
                    }
                } else {
                    aiResult = result
                }
            } catch {
                TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                print("Synthesis failed: \(error)")
            }
        }
    }
    
    private func expandStub() {
        // Implementation logic: Ask LLM to fill missing details based on context
        print("Expanding stub for \(page.title)")
    }
    
    private func findRelatedLinks() {
        // Implementation logic: Trigger a partial AI Link Scan for this page
        print("Finding related links for \(page.title)")
        store.runPartialAIScan(for: page)
    }

    // MARK: - Navigation

    /// 根据页面标题导航到对应页面
    /// 导航到指定页面
    /// - Parameter title: 目标页面的标题
    /// - Note: 如果找不到对应页面，则不进行导航。属于“智元”核心导航逻辑。
    private func navigateToPage(_ title: String) {
        if let target = store.pages.first(where: { $0.title == title }) {
            store.navigationPath.append(target)
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
    @EnvironmentObject var store: KMStore
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localized.tr("misc.close")) { dismiss() }
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
                        
                        MarkdownRendererView(content: content, onLinkTap: { _ in })
                    }
                    .padding()
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text(Localized.tr("misc.cancel"))
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
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.wikiBackground)
        }
    }
}

// MARK: - Export Helpers
extension PageDetailView {
    /// 将页面内容导出为临时 Markdown 文件 URL，以便支持系统级分享（AirDrop, 微信等）
    private func exportMarkdownFile() -> URL? {
        let content = """
        ---
        title: \(page.title)
        type: \(page.type.rawValue)
        tags: \(page.tags.joined(separator: ", "))
        ---
        
        # \(page.title)
        
        \(page.content)
        """
        
        // 清理文件名中的非法字符
        let safeTitle = page.title.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let fileName = "\(safeTitle).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
    
    private func copyToClipboard() {
        let content = """
        # \(page.title)
        
        \(page.content)
        """
        WikiPasteboard.string = content
        HapticManager.shared.trigger(.success)
    }
}

