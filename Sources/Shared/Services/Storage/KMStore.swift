import SwiftUI
import Combine

/// 智元知识库的核心存储与调度中枢 (Facade)。
///
/// `KMStore` 采用门面模式 (Facade Pattern)，统一协调持久化、AI 计算、双向链接及系统集成服务。
/// 它是整个应用的状态源 (Single Source of Truth)，通过 `ObservableObject` 驱动 SwiftUI 视图刷新。
///
/// ### 使用示例
/// ```swift
/// let store = KMStore()
/// let newPage = store.createPage(title: "新灵感", type: .idea)
/// ```
class KMStore: ObservableObject, GraphDataProvider {
    // MARK: - GraphDataProvider Conformance
    var isAIProcessing: Bool { llmService.isProcessing }
    
    func requestRelayout() {
        // 触发 objectWillChange 以通知视图层重新布局
        objectWillChange.send()
    }
    
    // MARK: - 专项服务 (L0 - L2 映射：基于 DI 注入)
    @Inject var sqliteStore: SQLiteStore
    @Inject var linkService: LinkService
    @Inject var lintService: LintService
    @Inject var ingestService: IngestService
    @Inject var logService: LogServiceProtocol
    @Inject var undoService: UndoService
    @Inject var backupService: BackupService
    @Inject var deepLinkService: DeepLinkService
    @Inject var accessibilityService: AccessibilityService
    @Inject var performanceService: PerformanceService
    @Inject var llmService: LLMServiceProtocol
    @Inject var snapshotService: SnapshotService
    @Inject var insightService: KnowledgeInsightService
    @Inject var securityService: VaultSecurityService
    
    private let clusteringService = GraphClusteringService() 
    private var searchTask: Task<Void, Never>? 
    private var cancellables = Set<AnyCancellable>()
    
    @Published var clusters: [GraphClusteringService.Cluster] = []

    // MARK: - UI State
    @Published var searchText: String = ""
    @Published var searchResults: [WikiPage] = []
    @Published var selectedPageID: UUID? {
        didSet {
            if let id = selectedPageID {
                if selectedTool != nil { selectedTool = nil }
                if let page = pages.first(where: { $0.id == id }) {
                    addToHistory(page)
                }
            }
        }
    }
    @Published var navigationHistory: [WikiPage] = []
    @Published var lintIssues: [LintIssue] = []
    @Published var navigationPath = NavigationPath()
    @Published var showPerfDashboard = false
    @Published var isPrivacyModeEnabled = false // 隐私模式：模糊处理标记为 #private 的内容
    
    private func addToHistory(_ page: WikiPage) {
        if navigationHistory.last?.id == page.id { return }
        navigationHistory.append(page)
        if navigationHistory.count > AppConfig.historyLimit { 
            navigationHistory.removeFirst()
        }
    }
    
    // MARK: - AI 维护状态 (Karpathy 模式)
    @Published var refactorSuggestions: [RefactorSuggestion] = []
    @Published var potentialLinks: [PotentialLinkSuggestion] = []
    @Published var isScanningAI = false
    @Published var isAdvancedSearching = false
    @Published var lastSearchDiagnostic: SearchDiagnosticInfo?
    @Published var weeklyInsight: KnowledgeInsightService.WeeklyInsight?

    /// 当前选中的工具视图（用于驱动 NavigationSplitView 三级结构中的中间列内容）
    @Published var selectedTool: ToolItem? {
        didSet {
            if selectedTool != nil && selectedPageID != nil {
                selectedPageID = nil
            }
        }
    }

    /// 工具视图枚举，用于三级 NavigationSplitView 导航
    enum ToolItem: String, CaseIterable, Hashable {
        case index
        case chat
        case log
        case lint
        case tagCloud
        case collab
        case taskCenter
        case weeklyReport
        case dashboard
        case pluginMarket
    }

    // MARK: - Convenience Accessors (forward to SQLiteStore)
    var pages: [WikiPage] { sqliteStore.pages }
    var logEntries: [LogEntry] { logService.logEntries }

    var totalPages: Int { sqliteStore.totalPages }
    var entityCount: Int { sqliteStore.entityCount }
    var conceptCount: Int { sqliteStore.conceptCount }
    var sourceCount: Int { sqliteStore.sourceCount }
    var stubCount: Int { sqliteStore.stubCount }
    var activeCount: Int { sqliteStore.activeCount }
    var totalWords: Int { sqliteStore.totalWords }

    // MARK: - 初始化
    init() {
        // 核心服务现已通过 @Inject 自动解析
        
        // 插件与分析初始化
        PluginRegistry.shared.analytics = LocalAnalyticsService.shared
        LocalAnalyticsService.shared.trackEvent("app_launched")
        
        setupServiceBindings()
        seedInitialDataIfNeeded()
        updateInitialMetrics()
        
        // 绑定插件数据提供者，确保沙盒内的查询能访问到真实数据
        PluginRegistry.shared.pagesProvider = { [weak self] in
            self?.sqliteStore.pages ?? []
        }
    }

    /// 设置各个服务之间的联动绑定
    private func setupServiceBindings() {
        // 配置 SQLiteStore 回调
        sqliteStore.onLog = { [weak self] action, target, details in
            self?.logService.addLog(action: action, target: target, details: details)
        }
        sqliteStore.onSaveNeeded = { [weak self] in
            // 触发 objectWillChange 以确保 SwiftUI 捕捉到副作用
            self?.objectWillChange.send()
        }

        // 监听 LLM 状态变更
        if let llm = llmService as? LLMService {
            llm.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
        
        // 监听存储层的页面变更
        sqliteStore.$pages
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        logService.logEntriesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        undoService.$canUndo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        undoService.$canRedo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        $searchText
            .debounce(for: .milliseconds(AppConfig.searchDebounceMS), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task {
                    // 使用混合检索 (RRF: Keyword + Semantic)
                    let hybridResult = await self.linkService.hybridSearchWithDiagnostics(
                        query: query,
                        in: self.sqliteStore.pages,
                        embeddingManager: self.sqliteStore.embeddingManager
                    )
                    
                    if Task.isCancelled { return }
                    
                    await MainActor.run {
                        self.searchResults = hybridResult.results
                        // 如果有高级诊断需求，可以在这里赋值诊断信息
                    }
                }
            }
            .store(in: &cancellables)
        
        backupService.$backupEntries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        deepLinkService.$pendingDeepLink
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        securityService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// 如果数据库为空，植入默认欢迎内容
    private func seedInitialDataIfNeeded() {
        if sqliteStore.pages.isEmpty {
            sqliteStore.seedDefaultContent { [weak self] action, target, details in
                self?.logService.addLog(action: action, target: target, details: details)
            }
        }
    }

    /// 更新初始指标和索引
    private func updateInitialMetrics() {
        if !sqliteStore.pages.isEmpty {
            performanceService.updatePageMetrics(pages: sqliteStore.pages)
            deepLinkService.indexPages(sqliteStore.pages)
        }
    }

    /// 创建一个新的知识页面。
    ///
    /// - Parameters:
    ///   - title: 页面标题，需保持唯一性。
    ///   - type: 页面类型，决定了初始图标和分类。
    ///   - customIcon: 可选的自定义 SF Symbols 图标名称。
    ///   - content: 初始 Markdown 内容。
    ///   - tags: 初始标签列表。
    ///   - forceDeepScan: 是否立即触发 AI 语义深度扫描。
    /// - Returns: 创建成功的 `WikiPage` 实例。
    @discardableResult
    func createPage(title: String, type: PageType, customIcon: String? = nil, content: String = "", tags: [String] = [], forceDeepScan: Bool = false) -> WikiPage {
        // 插件拦截处理
        let processedContent = PluginRegistry.shared.applyPreProcess(to: content)
        
        undoService.pushSnapshot(sqliteStore.pages)
        let page = sqliteStore.createPage(title: title, type: type, customIcon: customIcon, content: processedContent, tags: tags, forceDeepScan: forceDeepScan)
        backupService.markDirty()
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        return page
    }

    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        // 插件拦截处理
        var updatedPage = page
        updatedPage.content = PluginRegistry.shared.applyPreProcess(to: page.content)
        
        // 在更新前保存物理快照
        if let current = sqliteStore.pageByID(page.id) {
            snapshotService.saveSnapshot(for: current)
        }
        undoService.pushSnapshot(sqliteStore.pages)
        sqliteStore.updatePage(updatedPage, forceDeepScan: forceDeepScan)
        backupService.markDirty()
        deepLinkService.indexPages(sqliteStore.pages)
    }

    func deletePage(_ page: WikiPage) {
        undoService.pushSnapshot(sqliteStore.pages)
        sqliteStore.deletePage(page) { [weak self] deletedID in
            guard let self = self else { return false }
            if self.selectedPageID == deletedID {
                self.selectedPageID = nil
                return true
            }
            return false
        }
        backupService.markDirty()
        deepLinkService.deindexPage(id: page.id)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
    }
    
    // MARK: - Undo / Redo
    func undo() {
        guard let previous = undoService.undo(currentPages: sqliteStore.pages) else { return }
        sqliteStore.replaceAllPages(previous)
        deepLinkService.indexPages(sqliteStore.pages)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        logService.addLog(action: Localized.tr("logAction.undo"), target: Localized.tr("logAction.undo"), details: "")
    }
    
    func redo() {
        guard let next = undoService.redo(currentPages: sqliteStore.pages) else { return }
        sqliteStore.replaceAllPages(next)
        deepLinkService.indexPages(sqliteStore.pages)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        logService.addLog(action: Localized.tr("logAction.redo"), target: Localized.tr("logAction.redo"), details: "")
    }

    // MARK: - Link Resolution (delegates to LinkService)
    func pageByTitle(_ title: String) async -> WikiPage? {
        await linkService.pageByTitle(title, in: sqliteStore.pages) ?? sqliteStore.pageByTitle(title)
    }

    func getBacklinks(for pageID: UUID) async -> [WikiPage] {
        // 使用高效的 O(1) 数据库索引查询，替代原有的全表扫描
        sqliteStore.fetchBacklinksByID(for: pageID)
    }

    func pageByID(_ id: UUID) async -> WikiPage? {
        await linkService.pageByID(id, in: sqliteStore.pages) ?? sqliteStore.pageByID(id)
    }

    // MARK: - Search (delegates to LinkService)
    // searchResults 现在通过 searchText 的 sink 异步更新

    /// 执行 AI 驱动的高级混合检索。
    ///
    /// 该过程包含：查询改写 (QR) -> 混合召回 (Hybrid Recall) -> AI 智能重排 (Rerank)。
    ///
    /// - Parameter query: 原始搜索关键词。
    /// - Returns: 经过语义优化和重要性排序后的页面数组。
    func performAdvancedSearch(query: String) async -> [WikiPage] {
        guard !query.isEmpty else { return pages }
        
        await MainActor.run { 
            isAdvancedSearching = true 
            lastSearchDiagnostic = nil
        }
        
        // 1. 查询改写 (Query Rewrite)
        let rewrittenQuery = await llmService.rewriteQuery(query)
        
        // 2. 混合召回 (Hybrid Recall with RRF) - 使用带诊断信息的版本
        let hybridResult = await linkService.hybridSearchWithDiagnostics(
            query: rewrittenQuery, 
            in: pages, 
            embeddingManager: sqliteStore.embeddingManager
        )
        let candidates = hybridResult.results
        
        // 记录初步诊断信息
        await MainActor.run {
            self.lastSearchDiagnostic = SearchDiagnosticInfo(
                query: query,
                rewrittenQuery: rewrittenQuery,
                ftsCount: candidates.count, // 这里简化
                vectorCount: hybridResult.diagnostics.count,
                rrfTopResults: hybridResult.diagnostics
            )
        }
        
        // 3. AI 智能重排 (AI Rerank) - 仅对 Top 10 进行精排以平衡性能
        let topCandidates = Array(candidates.prefix(AppConfig.rerankTopLimit))
        let remaining = candidates.count > AppConfig.rerankTopLimit ? Array(candidates.dropFirst(AppConfig.rerankTopLimit)) : []
        
        let reranked = (try? await llmService.rerank(query: query, candidates: topCandidates)) ?? topCandidates
        
        await MainActor.run { isAdvancedSearching = false }
        return reranked + remaining
    }

    // MARK: - Tag Aggregation (delegates to LinkService)
    func getAllTags() async -> [(tag: String, count: Int)] {
        await linkService.allTags(in: sqliteStore.pages)
    }

    /// 重命名页面：更新标题并同步所有双向链接引用
    func renamePage(_ page: WikiPage, to newTitle: String) {
        let oldTitle = page.title
        var updated = page
        updated.title = newTitle
        sqliteStore.updatePage(updated, forceDeepScan: false)
        
        // 同步更新所有引用该页面的链接
        for i in sqliteStore.pages.indices {
            let p = sqliteStore.pages[i]
            if p.content.contains("[[\(oldTitle)]]") {
                var refPage = p
                refPage.content = refPage.content.replacingOccurrences(of: "[[\(oldTitle)]]", with: "[[\(newTitle)]]")
                sqliteStore.updatePage(refPage, forceDeepScan: false)
            }
        }
        
        backupService.markDirty()
        objectWillChange.send()
    }

    /// 重命名标签：将所有页面中的 oldTag 替换为 newTag
    func renameTag(_ oldTag: String, to newTag: String) {
        for page in sqliteStore.pages where page.tags.contains(oldTag) {
            var updated = page
            updated.tags = updated.tags.map { $0 == oldTag ? newTag : $0 }
            sqliteStore.updatePage(updated, forceDeepScan: false)
        }
        backupService.markDirty()
    }

    /// 删除标签：从所有页面中移除指定标签
    func deleteTag(_ tag: String) {
        for page in sqliteStore.pages where page.tags.contains(tag) {
            var updated = page
            updated.tags.removeAll { $0 == tag }
            sqliteStore.updatePage(updated, forceDeepScan: false)
        }
        backupService.markDirty()
    }

    /// 批量删除多个标签
    func deleteTags(_ tags: Set<String>) {
        for tag in tags {
            deleteTag(tag)
        }
        objectWillChange.send()
    }

    // MARK: - AI 维护操作
    
    /// 运行 AI 扫描，发现重构机会和潜在链接
    func runAIScan() async {
        guard llmService.isEnabled else { return }
        
        await MainActor.run { isScanningAI = true }
        let taskID = TaskCenter.shared.addTask(type: .ai, name: Localized.tr("aitask.scanTaskName"), target: "System")
        
        do {
            // 1. 获取重构建议（随机抽取一部分页面进行分析，避免 Token 过载）
            let samplePages = Array(sqliteStore.pages.prefix(10))
            let suggestions = try await llmService.analyzeForRefactoring(pages: samplePages)
            
            // 2. 发现潜在链接（针对最近活跃的页面）
            let activePages = sqliteStore.pages.sorted(by: { $0.updated > $1.updated }).prefix(5)
            let existingTitles = sqliteStore.pages.map { $0.title }
            
            var tempLinks: [PotentialLinkSuggestion] = []
            var seenLinks = Set<String>()
            for page in activePages {
                let found = try await llmService.discoverPotentialLinks(content: page.content, existingTitles: existingTitles)
                // 仅添加不存在于当前页面的新链接，并排重
                for title in Set(found) {
                    let linkKey = "\(page.id.uuidString)-\(title)"
                    if !seenLinks.contains(linkKey) && !page.content.contains("[[\(title)]]") {
                        seenLinks.insert(linkKey)
                        tempLinks.append(PotentialLinkSuggestion(sourcePageID: page.id, sourceTitle: page.title, targetTitle: title))
                    }
                }
            }
            let capturedLinks = tempLinks
            
            await MainActor.run {
                self.refactorSuggestions = suggestions
                self.potentialLinks = capturedLinks
                self.isScanningAI = false
                TaskCenter.shared.updateTask(taskID, status: .completed)
            }
        } catch {
            logService.addLog(action: "AI 扫描失败", target: "系统", details: error.localizedDescription)
            await MainActor.run { 
                isScanningAI = false 
                TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
            }
        }
    }
    
    /// 应用重构建议
    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) {
        // 根据类型执行具体操作 (示例：重命名)
        if suggestion.type == "rename", let page = sqliteStore.pages.first(where: { $0.title == suggestion.target }) {
            renamePage(page, to: suggestion.suggestion)
        }
        refactorSuggestions.removeAll { $0.id == suggestion.id }
    }
    
    /// 应用潜在链接建议
    func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) {
        if let index = sqliteStore.pages.firstIndex(where: { $0.id == suggestion.sourcePageID }) {
            var page = sqliteStore.pages[index]
            // 简单追加链接到末尾
            page.content += "\n\n相关链接: [[\(suggestion.targetTitle)]]"
            updatePage(page, forceDeepScan: false)
        }
        potentialLinks.removeAll { $0.id == suggestion.id }
    }
    
    /// 生成知识周报
    func generateWeeklyInsight() async {
        guard llmService.isEnabled else { return }
        do {
            let insight = try await insightService.generateWeeklyInsight(pages: sqliteStore.pages, llmService: llmService)
            await MainActor.run {
                self.weeklyInsight = insight
            }
        } catch {
            print("[Weekly Insight] Error: \(error)")
        }
    }

    // MARK: - Lint (delegates to LintService)
    func runLint() async {
        let issues = await lintService.runLint(pages: sqliteStore.pages, linkService: linkService)
        await MainActor.run {
            self.lintIssues = issues
            logService.addLog(action: Localized.tr("logAction.lint"), target: Localized.tr("logAction.healthCheck"), details: String(format: Localized.tr("logAction.lintIssuesFound"), lintIssues.count))
        }
    }

    // MARK: - Ingest (delegates to IngestService)
    /// 带智能折叠的摄入：如果标题已存在，则融合内容；否则创建新页面
    func ingestWithFolding(title: String, content: String, type: PageType = .source, forceDeepScan: Bool = false) async throws -> WikiPage {
        if let existingPage = sqliteStore.pageByTitle(title) {
            // 触发折叠流程 (Folding)前保存快照
            snapshotService.saveSnapshot(for: existingPage)
            
            let mergedContent = try await llmService.foldContent(
                existingContent: existingPage.content,
                newContent: content,
                title: title
            )
            
            var updatedPage = existingPage
            updatedPage.content = mergedContent
            updatedPage.updated = Date()
            sqliteStore.updatePage(updatedPage, forceDeepScan: forceDeepScan)
            
            await MainActor.run {
                self.loadFromDisk()
            }
            logService.addLog(action: "增量折叠", target: title, details: "新资料已融入现有页面")
            return updatedPage
        } else {
            // 常规摄入
            let page = ingestRawContent(title: title, content: content, type: type, forceDeepScan: forceDeepScan)
            return page
        }
    }

    func ingestRawContent(title: String, content: String, type: PageType = .source, forceDeepScan: Bool = false) -> WikiPage {
        undoService.pushSnapshot(sqliteStore.pages)
        let page = ingestService.ingestRawContent(
            title: title,
            content: content,
            type: type,
            forceDeepScan: forceDeepScan,
            llmService: llmService,
            pageStore: sqliteStore  // SQLiteStore conforms to same interface as PageStore
        )
        backupService.markDirty()
        deepLinkService.indexPages(sqliteStore.pages)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        return page
    }

    func ingestURL(_ urlString: String, forceDeepScan: Bool = true) async throws -> WikiPage {
        let page = try await ingestService.ingestURL(urlString: urlString, forceDeepScan: forceDeepScan, llmService: llmService, pageStore: sqliteStore)
        await MainActor.run {
            self.loadFromDisk()
        }
        return page
    }

    func ingestDocument(at url: URL) -> WikiPage? {
        undoService.pushSnapshot(sqliteStore.pages)
        let page = ingestService.ingestDocument(
            at: url,
            pageStore: sqliteStore
        )
        if page != nil {
            backupService.markDirty()
            deepLinkService.indexPages(sqliteStore.pages)
            performanceService.updatePageMetrics(pages: sqliteStore.pages)
        }
        return page
    }

    /// 仅提取文件内容，不存入数据库 (供预入库预览使用)
    /// - Parameter url: 外部文件 URL
    /// - Returns: 提取出的标题和正文内容。若不支持或提取失败则返回 nil。
    func extractText(from url: URL) -> (title: String, content: String)? {
        let format = DocumentFormat.detectFormat(from: url)
        let title = url.deletingPathExtension().lastPathComponent
        let content: String?

        switch format {
        case .docx:
            content = ingestService.extractTextFromDocx(at: url)
        case .xlsx:
            content = ingestService.extractTextFromXlsx(at: url)
        case .markdown, .plainText:
            content = try? String(contentsOf: url, encoding: .utf8)
        case .pdf:
            content = PDFService.extractText(from: url)
        case .unknown:
            return nil
        }

        guard let text = content, !text.isEmpty else { return nil }
        return (title, text)
    }

    /// 仅抓取 URL 内容，不存入数据库 (供预览使用)
    func fetchURLContent(urlString: String) async throws -> (title: String, content: String) {
        let result = try await ingestService.scraper.fetchMarkdown(from: urlString)
        var content = result.markdown
        
        // 语义增强
        content = await ingestService.enrichRichContent(content, llm: llmService)
        
        return (result.title, content)
    }

    // MARK: - Logging (delegates to LogService)
    func addLog(action: String, target: String, details: String = "") {
        logService.addLog(action: action, target: target, details: details)
    }

    // MARK: - Bulk Operations
    func resetAllData() {
        sqliteStore.removeAllPages()
        if let logSvc = logService as? LogService {
            logSvc.logEntries.removeAll()
        }
        lintIssues.removeAll()
        undoService.clear()
        // Remove SQLite database file
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3-wal"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3-shm"))
        // Also clean JSON/UserDefaults fallbacks for migration completeness
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(AppConfig.pagesFileName))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(AppConfig.logsFileName))
        UserDefaults.standard.removeObject(forKey: AppConfig.pagesFileName.replacingOccurrences(of: ".json", with: ""))
        UserDefaults.standard.removeObject(forKey: AppConfig.logsFileName.replacingOccurrences(of: ".json", with: ""))
        deepLinkService.deindexAllPages()
    }

    func addImportedPage(_ page: WikiPage) {
        undoService.pushSnapshot(sqliteStore.pages)
        var newPage = page
        newPage.id = UUID()
        sqliteStore.pages.append(newPage)
        deepLinkService.indexPages(sqliteStore.pages)
    }

    /// Insert a page received from a remote collaboration peer.
    /// Does NOT push undo snapshot since this is a remote change.
    func insertRemotePage(_ page: WikiPage) {
        if !sqliteStore.pages.contains(where: { $0.id == page.id }) {
            sqliteStore.pages.append(page)
            deepLinkService.indexPages(sqliteStore.pages)
        }
    }

    func seedDefaultContent() {
        if sqliteStore.pages.isEmpty {
            sqliteStore.seedDefaultContent { [weak self] action, target, details in
                self?.logService.addLog(action: action, target: target, details: details)
            }
        }
    }

    // MARK: - Persistence (SQLite auto-persists; only log needs explicit save + backup)
    func saveToDisk() {
        performanceService.measure("save") {
            logService.saveToDisk()
        }
        backupService.createBackup(pages: sqliteStore.pages)
        backupService.markClean()
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
    }

    func loadFromDisk() {
        performanceService.measure("load") {
            sqliteStore.reloadFromDisk()
            logService.loadFromDisk()
        }
        deepLinkService.indexPages(sqliteStore.pages)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
    }
    
    // MARK: - Deep Link Handling
    func handleDeepLink(_ url: URL) -> Bool {
        deepLinkService.handleURL(url)
    }
    
    func consumeDeepLink() {
        guard let link = deepLinkService.consumeDeepLink() else { return }
        switch link {
        case .openPage(let id):
            selectedPageID = id
        case .openPageByTitle(let title):
            Task {
                if let page = await pageByTitle(title) {
                    await MainActor.run {
                        self.selectedPageID = page.id
                    }
                }
            }
        case .search(let query):
            searchText = query
        case .ingest, .graph, .chat:
            break // Tab navigation handled by ContentView
        }
    }
    
    // MARK: - File System Sync (Karpathy Pattern)
    func exportToFolder(at url: URL) throws {
        let syncService = FileSystemSyncService()
        try syncService.exportToMarkdown(pages: sqliteStore.pages, destinationURL: url)
        logService.addLog(action: "物理同步", target: "全库导出", details: "知识库已同步至 \(url.lastPathComponent)")
    }
    
    func runPartialAIScan(for page: WikiPage) {
        // Logic to trigger AI link suggestions only for this page
        // For now, it could just refresh the global suggestions and filter
        Task {
            await runAIScan()
        }
    }
    
    // MARK: - Stats & Insights
    
    struct KnowledgeGrowthPoint: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }
    
    var growthSeries: [KnowledgeGrowthPoint] {
        let allPages = sqliteStore.pages.sorted { $0.created < $1.created }
        guard !allPages.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var series: [KnowledgeGrowthPoint] = []
        
        // 计算过去 30 天的每日累计总数
        for daysAgo in (0...30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
                let count = allPages.filter { $0.created <= date }.count
                series.append(KnowledgeGrowthPoint(date: date, count: count))
            }
        }
        return series
    }
    
    // MARK: - Clustering
    
    func updateClusters(k: Int = 5) {
        // 获取所有有向量的页面（实际应用从数据库获取已有向量）
        let _ = sqliteStore.embeddingManager.vectorizeChunks(chunks: pages.map { $0.title })
        // 使用已有向量进行聚类
        let allEmbeddings = sqliteStore.embeddingManager.allEmbeddings
        clusters = clusteringService.cluster(pages: pages, embeddings: allEmbeddings, k: k)
    }
    
    /// 寻找语义相似的页面 (Semantic Recommendation)
    func findSimilarPages(for page: WikiPage, limit: Int = 3) -> [WikiPage] {
        let cache = sqliteStore.embeddingManager.allEmbeddings
        guard let pageEmbedding = cache[page.id] else {
            return []
        }

        // 过滤掉当前页面
        let candidates = sqliteStore.pages.filter { $0.id != page.id }

        let scored = candidates.compactMap { candidate -> (WikiPage, Float)? in
            guard let candidateEmbedding = cache[candidate.id] else {
                return nil
            }
            let score = EmbeddingManager.cosineSimilarity(pageEmbedding, candidateEmbedding)
            return (candidate, score)
        }

        return scored
            .filter { $0.1 > 0.65 } // 相似度阈值
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    /// 挂载外部文件夹 (External Vault)
    func mountVault(at url: URL) {
        // 请求文件夹访问权限 (macOS/iOS Scoped URL)
        guard url.startAccessingSecurityScopedResource() else {
            addLog(action: "外部同步", target: url.lastPathComponent, details: "获取权限失败")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let externalPages = VaultService.shared.scan(directory: url)
        
        undoService.pushSnapshot(sqliteStore.pages)
        var newCount = 0
        var updateCount = 0
        
        for extPage in externalPages {
            // 根据标题判断是否存在
            if let existingIndex = sqliteStore.pages.firstIndex(where: { $0.title == extPage.title }) {
                // 如果外部内容更新，则更新本地内容
                if sqliteStore.pages[existingIndex].content != extPage.content {
                    sqliteStore.pages[existingIndex].content = extPage.content
                    updateCount += 1
                }
            } else {
                // 创建新页面
                let newPage = WikiPage(
                    title: extPage.title,
                    type: .source,
                    content: extPage.content,
                    sourceURL: extPage.url.path
                )
                sqliteStore.pages.append(newPage)
                newCount += 1
            }
        }
        
        addLog(action: "外部同步", target: url.lastPathComponent, details: "新增 \(newCount) 页，更新 \(updateCount) 页")
        saveToDisk()
    }
}
