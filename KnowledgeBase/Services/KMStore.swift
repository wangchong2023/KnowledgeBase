import SwiftUI
import Combine

// MARK: - KM Store (Facade)
/// Coordinating facade that composes SQLiteStore (persistence), LinkService, LintService, IngestService,
/// LogService, UndoService, BackupService, DeepLinkService, AccessibilityService, and PerformanceService.
/// Views still reference `store` — internal logic is delegated to specialized services.
class KMStore: ObservableObject {
    // MARK: - Services
    let sqliteStore = SQLiteStore()
    let linkService = LinkService()
    let lintService = LintService()
    let ingestService = IngestService()
    let logService = LogService()
    let undoService = UndoService()
    let backupService = BackupService()
    let deepLinkService = DeepLinkService()
    let accessibilityService = AccessibilityService()
    let performanceService = PerformanceService()

    // MARK: - UI State
    @Published var searchText: String = ""
    @Published var selectedPageID: UUID?
    @Published var lintIssues: [LintIssue] = []
    @Published var navigationPath = NavigationPath()

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

    // MARK: - Init
    init() {
        // Wire up SQLiteStore callbacks
        sqliteStore.onLog = { [weak self] action, target, details in
            self?.logService.addLog(action: action, target: target, details: details)
        }
        sqliteStore.onSaveNeeded = { [weak self] in
            // Trigger objectWillChange so SwiftUI picks up any side effects
            self?.objectWillChange.send()
        }

        // Forward SQLiteStore changes to KMStore's objectWillChange
        sqliteStore.$pages
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        logService.$logEntries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Forward UndoService changes
        undoService.$canUndo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        undoService.$canRedo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Forward BackupService changes
        backupService.$backupEntries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Forward DeepLinkService changes
        deepLinkService.$pendingDeepLink
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Seed default content if empty
        if sqliteStore.pages.isEmpty {
            sqliteStore.seedDefaultContent { [weak self] action, target, details in
                self?.logService.addLog(action: action, target: target, details: details)
            }
        }
        
        // Update performance metrics
        if !sqliteStore.pages.isEmpty {
            performanceService.updatePageMetrics(pages: sqliteStore.pages)
        }
        
        // Index pages for Spotlight
        if !sqliteStore.pages.isEmpty {
            deepLinkService.indexPages(sqliteStore.pages)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - CRUD (delegates to SQLiteStore, with undo + backup support)
    @discardableResult
    func createPage(title: String, type: PageType, customIcon: String? = nil, content: String = "", tags: [String] = []) -> WikiPage {
        undoService.pushSnapshot(sqliteStore.pages)
        let page = sqliteStore.createPage(title: title, type: type, customIcon: customIcon, content: content, tags: tags)
        backupService.markDirty()
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        return page
    }

    func updatePage(_ page: WikiPage) {
        undoService.pushSnapshot(sqliteStore.pages)
        sqliteStore.updatePage(page)
        backupService.markDirty()
        deepLinkService.indexPages(sqliteStore.pages)
    }

    func deletePage(_ page: WikiPage) {
        undoService.pushSnapshot(sqliteStore.pages)
        sqliteStore.deletePage(page) { [weak self] deletedID in
            if self?.selectedPageID == deletedID {
                self?.selectedPageID = nil
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
    func pageByTitle(_ title: String) -> WikiPage? {
        linkService.pageByTitle(title, in: sqliteStore.pages) ?? sqliteStore.pageByTitle(title)
    }

    func backlinks(for pageID: UUID) -> [WikiPage] {
        linkService.backlinks(for: pageID, in: sqliteStore.pages)
    }

    func pageByID(_ id: UUID) -> WikiPage? {
        linkService.pageByID(id, in: sqliteStore.pages) ?? sqliteStore.pageByID(id)
    }

    // MARK: - Search (delegates to LinkService)
    var searchResults: [WikiPage] {
        linkService.search(query: searchText, in: sqliteStore.pages)
    }

    // MARK: - Tag Aggregation (delegates to LinkService)
    var allTags: [(tag: String, count: Int)] {
        linkService.allTags(in: sqliteStore.pages)
    }

    /// 重命名标签：将所有页面中的 oldTag 替换为 newTag
    func renameTag(_ oldTag: String, to newTag: String) {
        for page in sqliteStore.pages where page.tags.contains(oldTag) {
            var updated = page
            updated.tags = updated.tags.map { $0 == oldTag ? newTag : $0 }
            sqliteStore.updatePage(updated)
        }
        backupService.markDirty()
    }

    /// 删除标签：从所有页面中移除指定标签
    func deleteTag(_ tag: String) {
        for page in sqliteStore.pages where page.tags.contains(tag) {
            var updated = page
            updated.tags.removeAll { $0 == tag }
            sqliteStore.updatePage(updated)
        }
        backupService.markDirty()
    }

    // MARK: - Lint (delegates to LintService)
    func runLint() {
        let result = performanceService.measure("lint") {
            lintService.runLint(pages: sqliteStore.pages, linkService: linkService)
        }
        lintIssues = result
        logService.addLog(action: Localized.tr("logAction.lint"), target: Localized.tr("logAction.healthCheck"), details: String(format: Localized.tr("logAction.lintIssuesFound"), lintIssues.count))
    }

    // MARK: - Ingest (delegates to IngestService)
    func ingestRawContent(title: String, content: String, type: PageType = .source) -> WikiPage {
        undoService.pushSnapshot(sqliteStore.pages)
        let page = ingestService.ingestRawContent(
            title: title,
            content: content,
            type: type,
            pageStore: sqliteStore  // SQLiteStore conforms to same interface as PageStore
        )
        backupService.markDirty()
        deepLinkService.indexPages(sqliteStore.pages)
        performanceService.updatePageMetrics(pages: sqliteStore.pages)
        return page
    }

    // MARK: - Logging (delegates to LogService)
    func addLog(action: String, target: String, details: String = "") {
        logService.addLog(action: action, target: target, details: details)
    }

    // MARK: - Bulk Operations
    func resetAllData() {
        sqliteStore.removeAllPages()
        logService.logEntries.removeAll()
        lintIssues.removeAll()
        undoService.clear()
        // Remove SQLite database file
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3-wal"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("km.sqlite3-shm"))
        // Also clean JSON/UserDefaults fallbacks for migration completeness
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("wikicraft_pages.json"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("wikicraft_logs.json"))
        UserDefaults.standard.removeObject(forKey: "wikicraft_pages")
        UserDefaults.standard.removeObject(forKey: "wikicraft_logs")
        deepLinkService.deindexAllPages()
    }

    func addImportedPage(_ page: WikiPage) {
        undoService.pushSnapshot(sqliteStore.pages)
        var newPage = page
        newPage.id = UUID()
        sqliteStore.pages.append(newPage)
        deepLinkService.indexPages(sqliteStore.pages)
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
            if let page = pageByTitle(title) {
                selectedPageID = page.id
            }
        case .search(let query):
            searchText = query
        case .ingest, .graph, .chat:
            break // Tab navigation handled by ContentView
        }
    }
}
