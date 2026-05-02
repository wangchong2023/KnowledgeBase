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
    var lintIssues: [LintIssue] = []
    var navigationPath = NavigationPath()
    var showPerfDashboard = false
    var isPrivacyModeEnabled = false 
    
    var refactorSuggestions: [RefactorSuggestion] = []
    var potentialLinks: [PotentialLinkSuggestion] = []
    var isScanningAI = false
    var isAdvancedSearching = false
    var lastSearchDiagnostic: SearchDiagnosticInfo?
    var weeklyInsight: KnowledgeInsightService.WeeklyInsight?
    var selectedTool: ToolItem?

    enum ToolItem: String, CaseIterable, Hashable {
        case index, chat, log, lint, tagCloud, collab, taskCenter, weeklyReport, dashboard, pluginMarket
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

    func runLint() { Task { let issues = await lintService.runLint(pages: pages, linkService: linkService); await MainActor.run { self.lintIssues = issues } } }
    func runAIScan() async { isScanningAI = true; try? await Task.sleep(nanoseconds: 1_000_000_000); isScanningAI = false }
    func generateWeeklyInsight() async { try? await Task.sleep(nanoseconds: 500_000_000) }
    func runPartialAIScan(for page: WikiPage) { Task { await runAIScan() } }
    func applyRefactorSuggestion(_ s: RefactorSuggestion) {}
    func applyPotentialLink(_ l: PotentialLinkSuggestion) {}
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
