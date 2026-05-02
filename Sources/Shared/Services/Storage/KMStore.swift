@preconcurrency import SwiftUI
@preconcurrency import Combine
import Observation

@MainActor
@Observable
final class KMStore: @preconcurrency GraphDataProvider {
    var isAIProcessing: Bool { llmService.isProcessing }
    func requestRelayout() {}
    
    @ObservationIgnored @Inject var sqliteStore: SQLiteStore
    @ObservationIgnored @Inject var linkService: LinkService
    @ObservationIgnored @Inject var lintService: LintService
    @ObservationIgnored @Inject var ingestService: IngestService
    @ObservationIgnored @Inject var logService: LogServiceProtocol
    @ObservationIgnored @Inject var undoService: UndoService
    @ObservationIgnored @Inject var backupService: BackupService
    @ObservationIgnored @Inject var deepLinkService: DeepLinkService
    @ObservationIgnored @Inject var accessibilityService: AccessibilityService
    @ObservationIgnored @Inject var performanceService: PerformanceService
    @ObservationIgnored @Inject var llmService: LLMServiceProtocol
    @ObservationIgnored @Inject var snapshotService: SnapshotService
    @ObservationIgnored @Inject var insightService: KnowledgeInsightService
    @ObservationIgnored @Inject var securityService: VaultSecurityService
    
    @ObservationIgnored private var searchTask: Task<Void, Never>? 
    
    var clusters: [GraphClusteringService.Cluster] = []
    var searchText: String = "" {
        didSet { performDebouncedSearch(query: searchText) }
    }
    var searchResults: [WikiPage] = []
    var selectedPageID: UUID?
    var navigationHistory: [WikiPage] = []
    
    @ObservationIgnored private var _lintIssues: [LintIssue] = {
        if let data = UserDefaults.standard.data(forKey: "lastLintIssues"),
           let decoded = try? JSONDecoder().decode([LintIssue].self, from: data) {
            return decoded
        }
        return []
    }()
    var lintIssues: [LintIssue] {
        get { access(keyPath: \.lintIssues); return _lintIssues }
        set {
            withMutation(keyPath: \.lintIssues) {
                _lintIssues = newValue
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: "lastLintIssues")
                }
            }
        }
    }

    var navigationPath = NavigationPath()
    var showPerfDashboard = false
    @ObservationIgnored private var _isPrivacyModeEnabled: Bool = UserDefaults.standard.object(forKey: "isPrivacyModeEnabled") as? Bool ?? true
    var isPrivacyModeEnabled: Bool {
        get {
            access(keyPath: \.isPrivacyModeEnabled)
            return _isPrivacyModeEnabled
        }
        set {
            withMutation(keyPath: \.isPrivacyModeEnabled) {
                _isPrivacyModeEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "isPrivacyModeEnabled")
            }
        }
    }
    
    @ObservationIgnored private var _isBiometricEnabled: Bool = UserDefaults.standard.object(forKey: "isBiometricEnabled") as? Bool ?? false
    var isBiometricEnabled: Bool {
        get {
            access(keyPath: \.isBiometricEnabled)
            return _isBiometricEnabled
        }
        set {
            withMutation(keyPath: \.isBiometricEnabled) {
                _isBiometricEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: "isBiometricEnabled")
            }
        }
    }
    
    var refactorSuggestions: [RefactorSuggestion] = []
    var potentialLinks: [PotentialLinkSuggestion] = []
    var isScanningAI = false
    var isAdvancedSearching = false
    var lastSearchDiagnostic: SearchDiagnosticInfo?
    var weeklyInsight: KnowledgeInsightService.WeeklyInsight?
    var selectedTool: ToolItem?

    @ObservationIgnored private var _lastLintScore: Int = UserDefaults.standard.integer(forKey: "lastLintScore")
    var lastLintScore: Int {
        get { access(keyPath: \.lastLintScore); return _lastLintScore }
        set { withMutation(keyPath: \.lastLintScore) { _lastLintScore = newValue; UserDefaults.standard.set(newValue, forKey: "lastLintScore") } }
    }
    
    @ObservationIgnored private var _lastLintDate: Date? = UserDefaults.standard.object(forKey: "lastLintDate") as? Date
    var lastLintDate: Date? {
        get { access(keyPath: \.lastLintDate); return _lastLintDate }
        set { withMutation(keyPath: \.lastLintDate) { _lastLintDate = newValue; UserDefaults.standard.set(newValue, forKey: "lastLintDate") } }
    }
    
    enum ToolItem: String, CaseIterable, Hashable {
        case index, chat, log, lint, tagCloud, collab, taskCenter, weeklyReport, dashboard, pluginMarket, synthesis
    }
    
    var pages: [WikiPage] { sqliteStore.pages }
    var logEntries: [LogEntry] { (logService as? LogService)?.logEntries ?? [] }
    var totalPages: Int { pages.count }
    var entityCount: Int { pages.filter { $0.type == .entity }.count }
    var conceptCount: Int { pages.filter { $0.type == .concept }.count }
    var sourceCount: Int { pages.filter { $0.type == .source }.count }
    var comparisonCount: Int { pages.filter { $0.type == .comparison }.count }
    var mapCount: Int { pages.filter { $0.type == .map }.count }
    var totalWords: Int { pages.reduce(0) { $0 + $1.wordCount } }
    var stubCount: Int { pages.filter { $0.isStub }.count }

    struct KnowledgeGrowthPoint: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    var growthSeries: [KnowledgeGrowthPoint] {
        let all = pages.sorted { $0.created < $1.created }
        guard !all.isEmpty else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var series: [KnowledgeGrowthPoint] = []
        for daysAgo in (0...30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
                let count = all.filter { $0.created <= date }.count
                series.append(KnowledgeGrowthPoint(date: date, count: count))
            }
        }
        return series
    }

    init() { seedDefaultContent() }

    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let res = await linkService.hybridSearchWithDiagnostics(query: query, in: pages, embeddingManager: sqliteStore.embeddingManager)
            if !Task.isCancelled { searchResults = res.results }
        }
    }

    func seedDefaultContent() {
        if pages.isEmpty {
            sqliteStore.seedDefaultContent { [weak self] a, t, d in self?.addLog(action: a, target: t, details: d) }
        }
    }

    @discardableResult
    func createPage(title: String, type: PageType, customIcon: String? = nil, content: String = "", tags: [String] = [], forceDeepScan: Bool = false) -> WikiPage {
        undoService.pushSnapshot(pages)
        let page = sqliteStore.createPage(title: title, type: type, customIcon: customIcon, content: content, tags: tags, forceDeepScan: forceDeepScan)
        backupService.markDirty()
        return page
    }

    func getBacklinks(for id: UUID) -> [WikiPage] { sqliteStore.fetchBacklinksByID(for: id) }
    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        undoService.pushSnapshot(pages)
        sqliteStore.updatePage(page, forceDeepScan: forceDeepScan)
        backupService.markDirty()
    }

    func deletePage(_ page: WikiPage) {
        undoService.pushSnapshot(pages)
        sqliteStore.deletePage(page) { [weak self] id in
            if self?.selectedPageID == id { self?.selectedPageID = nil; return true }
            return false
        }
    }

    func undo() { if let prev = undoService.undo(currentPages: pages) { sqliteStore.replaceAllPages(prev) } }
    func redo() { if let next = undoService.redo(currentPages: pages) { sqliteStore.replaceAllPages(next) } }

    func saveToDisk() { logService.saveToDisk(); backupService.createBackup(pages: pages) }
    func loadFromDisk() { sqliteStore.reloadFromDisk(); logService.loadFromDisk() }
    
    func addLog(action: String, target: String, details: String) { logService.addLog(action: action, target: target, details: details) }
    func handleDeepLink(_ url: URL) -> Bool { deepLinkService.handleURL(url) }
    func consumeDeepLink() {
        guard let link = deepLinkService.consumeDeepLink() else { return }
        switch link {
        case .openPage(let id): selectedPageID = id
        case .openPageByTitle(let t): Task { if let p = await pageByTitle(t) { await MainActor.run { self.selectedPageID = p.id } } }
        case .search(let q): searchText = q
        default: break
        }
    }

    func addImportedPage(_ page: WikiPage) {
        var p = page; p.id = UUID()
        sqliteStore.pages.append(p)
    }
    
    func insertRemotePage(_ page: WikiPage) { if !pages.contains(where: { $0.id == page.id }) { sqliteStore.pages.append(page) } }
    func clearAllData() throws {
        sqliteStore.pages.removeAll(); undoService.clear()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3"))
    }
    
    func pageByTitle(_ title: String) async -> WikiPage? { await linkService.pageByTitle(title, in: pages) }

    func extractText(from url: URL) -> (title: String, content: String)? {
        guard let page = ingestService.ingestDocument(at: url, pageStore: sqliteStore) else { return nil }
        return (page.title, page.content)
    }
    
    func ingestWithFolding(title: String, content: String, type: PageType, forceDeepScan: Bool) async throws -> WikiPage {
        return ingestService.ingestRawContent(title: title, content: content, type: type, forceDeepScan: forceDeepScan, llmService: llmService, pageStore: sqliteStore)
    }
    
    struct ExtractedURLContent { let title: String; let content: String }
    func fetchURLContent(urlString: String) async throws -> ExtractedURLContent {
        let result = try await ingestService.scraper.fetchMarkdown(from: urlString)
        return ExtractedURLContent(title: result.title, content: result.markdown)
    }

    func runLint() {
        Task {
            let issues = await lintService.runLint(pages: pages, linkService: linkService)
            await MainActor.run {
                self.lintIssues = issues
                self.lastLintDate = Date()
            }
        }
    }
    
    func runAIScan() async {
        guard llmService.isEnabled else { 
            logService.addLog(action: "AI 扫描跳过", target: "系统", details: "LLM 服务未启用")
            return 
        }
        
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
    
    func runPartialAIScan(for page: WikiPage) { Task { await runAIScan() } }
    
    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) {
        if suggestion.type == "rename", let page = sqliteStore.pages.first(where: { $0.title == suggestion.target }) {
            renamePage(page, to: suggestion.suggestion)
        }
    }
    
    func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) {
        if let index = sqliteStore.pages.firstIndex(where: { $0.id == suggestion.sourcePageID }) {
            var page = sqliteStore.pages[index]
            page.content += "\n\n相关链接: [[\(suggestion.targetTitle)]]"
            updatePage(page, forceDeepScan: false)
        }
        potentialLinks.removeAll { $0.id == suggestion.id }
    }
    
    func renamePage(_ page: WikiPage, to newTitle: String) {
        let oldTitle = page.title
        var updated = page
        updated.title = newTitle
        sqliteStore.updatePage(updated, forceDeepScan: false)
        
        for i in sqliteStore.pages.indices {
            let p = sqliteStore.pages[i]
            if p.content.contains("[[\(oldTitle)]]") {
                var refPage = p
                refPage.content = refPage.content.replacingOccurrences(of: "[[\(oldTitle)]]", with: "[[\(newTitle)]]")
                sqliteStore.updatePage(refPage, forceDeepScan: false)
            }
        }
        backupService.markDirty()
    }
    func findSimilarPages(for page: WikiPage, limit: Int = 3) -> [WikiPage] { [] }
    func mountVault(at url: URL) { }
    func resetAllData() { try? clearAllData() }
    func getAllTags() async -> [(tag: String, count: Int)] { await linkService.allTags(in: pages) }
    func performAdvancedSearch(query: String) async -> [WikiPage] {
        let res = await linkService.hybridSearchWithDiagnostics(query: query, in: pages, embeddingManager: sqliteStore.embeddingManager)
        return res.results
    }
    func renameTag(_ oldTag: String, to newTag: String) {
        for i in pages.indices { if let idx = pages[i].tags.firstIndex(of: oldTag) { var p = pages[i]; p.tags[idx] = newTag; updatePage(p, forceDeepScan: false) } }
    }
    func deleteTag(_ tag: String) {
        for i in pages.indices { if let idx = pages[i].tags.firstIndex(of: tag) { var p = pages[i]; p.tags.remove(at: idx); updatePage(p, forceDeepScan: false) } }
    }
}
