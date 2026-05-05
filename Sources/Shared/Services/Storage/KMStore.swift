// KMStore.swift
//
// 作者: Wang Chong
// 功能说明: KM存储.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI
@preconcurrency import Combine
@preconcurrency import PDFKit
import Observation

@MainActor
@Observable
final class KMStore: @preconcurrency GraphDataProvider {
    
    @ObservationIgnored @Inject var sqliteStore: SQLiteStore
    @ObservationIgnored @Inject var linkService: LinkService
    @ObservationIgnored @Inject var lintService: LintService
    @ObservationIgnored @Inject var logger: any LoggerProtocol
    @ObservationIgnored @Inject var undoService: UndoService
    @ObservationIgnored @Inject var backupService: BackupService
    @ObservationIgnored @Inject var ingestService: IngestService
    @ObservationIgnored @Inject var accessibilityService: AccessibilityService
    @ObservationIgnored @Inject var performanceService: PerformanceService
    @ObservationIgnored @Inject var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject var snapshotService: SnapshotService
    @ObservationIgnored @Inject var insightService: KnowledgeInsightService
    @ObservationIgnored @Inject var securityService: VaultStorageSecurityService
    
    // ── 职责解耦：子 Store 聚合 ──
    var searchStore: SearchStore!
    var settingsStore = SettingsStore()
    var aiWorkflowStore: AIWorkflowStore!

    var clusters: [GraphClusteringService.Cluster] = []
    var refreshTrigger = UUID()
    
    var showCreateSheet = false
    var showPerfDashboard = false
    
    // ── 协议适配：GraphDataProvider ──
    var isScanningAI: Bool { aiWorkflowStore.isScanningAI }
    var isAIProcessing: Bool { aiWorkflowStore.isProcessingPageAI }
    var isPrivacyModeEnabled: Bool { settingsStore.isPrivacyModeEnabled }
    
    func requestRelayout() {
        // 图谱布局由 GraphLayoutProcessor 处理，此处作为协议占位
        refreshTrigger = UUID()
    }
    
    func refresh() {
        logger.addLog(action: .systemInit, target: "KMStore", details: "Refreshing store. Current pages: \(sqliteStore.pages.count)")
        sqliteStore.reloadFromDisk()
        refreshTrigger = UUID()
        logger.addLog(action: .systemInit, target: "KMStore", details: "Refreshed. New pages count: \(sqliteStore.pages.count)")
    }

    // ── 健康度（由子 Store/Service 驱动） ──
    var healthMetrics: (score: Int, level: LintService.HealthLevel) {
        lintService.calculateHealthMetrics(issues: aiWorkflowStore.lintIssues)
    }
    var lintScore: Int { healthMetrics.score }
    var healthLevel: LintService.HealthLevel { healthMetrics.level }
    
    var lintIssues: [LintIssue] { aiWorkflowStore.lintIssues }
    var brokenLinkCount: Int { lintIssues.filter { $0.type == .brokenLink }.count }
    var orphanPageCount: Int { lintIssues.filter { $0.type == .island || $0.type == .orphan }.count }
    var totalConnectionCount: Int { pages.reduce(0) { $0 + $1.outgoingLinks.count } }
    
    enum ToolItem: String, CaseIterable, Hashable {
        case index, chat, log, lint, tagCloud, collab, taskCenter, weeklyReport, dashboard, pluginMarket, synthesis
    }

    // MARK: - Coach Marks
    enum CoachMarkType: String {
        case graphDiscovery
    }
    var pendingCoachMark: CoachMarkType?
    
    var pages: [WikiPage] {
        _ = refreshTrigger
        return sqliteStore.pages
    }
    var logEntries: [LogEntry] { (logger as? Logger)?.logEntries ?? [] }
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

    init() {
        // 核心修复：在任何子初始化之前完成自我注册，防止构造过程中的循环依赖导致注入失效
        ServiceContainer.shared.register(self, for: KMStore.self)
        
        // 子 Store 初始化（使用 @Inject 自动解析依赖）
        self.searchStore = SearchStore()
        self.aiWorkflowStore = AIWorkflowStore()
        
        logger.addLog(action: .systemInit, target: "KMStore", details: "init called")
        sqliteStore.onLog = { [weak self] a, t, d in
            self?.addLog(action: a, target: t, details: d)
        }
        seedDefaultContent() 
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

        if totalPages >= 3 && !settingsStore.hasShownGraphCoachMark {
            settingsStore.hasShownGraphCoachMark = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.pendingCoachMark = .graphDiscovery
                }
            }
        }

        let totalLinks = pages.reduce(0) { $0 + $1.outgoingLinks.count }
        WikiEventBus.shared.publish(.pageCreated(id: page.id, title: page.title, nodeCount: pages.count, linkCount: totalLinks))

        return page
    }

    func getBacklinks(for id: UUID) -> [WikiPage] { sqliteStore.fetchBacklinksByID(for: id) }
    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        undoService.pushSnapshot(pages)
        sqliteStore.updatePage(page, forceDeepScan: forceDeepScan)
        backupService.markDirty()
    }

    func savePage(_ page: WikiPage) {
        updatePage(page, forceDeepScan: false)
    }

    func deletePage(_ page: WikiPage) {
        undoService.pushSnapshot(pages)
        sqliteStore.deletePage(page)
    }

    func undo() { if let prev = undoService.undo(currentPages: pages) { sqliteStore.replaceAllPages(prev) } }
    func redo() { if let next = undoService.redo(currentPages: pages) { sqliteStore.replaceAllPages(next) } }

    func saveToDisk() {
        logger.saveToDisk()
        backupService.createBackup(pages: pages)
    }
    func loadFromDisk() { sqliteStore.reloadFromDisk(); logger.loadFromDisk() }
    
    func addLog(action: LogAction, target: String, details: String) { logger.addLog(action: action, target: target, details: details) }
    func clearLogs() { logger.clearAllLogs() }
}

// MARK: - KMStore 核心扩展
extension KMStore {
    func addImportedPage(_ page: WikiPage) {
        var p = page; p.id = UUID()
        sqliteStore.syncRemotePage(p)
    }

    /// 生成 AI 启发式问题（用于 Chat 视图的引导问题）
    func generateInsightfulQuestions() async throws -> [String] {
        try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)
    }
    
    func insertRemotePage(_ page: WikiPage) {
        sqliteStore.syncRemotePage(page)
    }
    
    func clearAllData() throws {
        sqliteStore.pages.removeAll()
        undoService.clear()
        sqliteStore.close()
        let dbURL = sqliteStore.dbPath
        try? FileManager.default.removeItem(at: dbURL)

        aiWorkflowStore.clearAll()
        searchStore.clearAll()
        settingsStore.reset()

        UserDefaults.standard.removeObject(forKey: "has_seeded_initial_content")

        WikiEventBus.shared.publish(.pagesCleared)
        refresh()
    }
    
    func pageByTitle(_ title: String) async -> WikiPage? { await linkService.pageByTitle(title, in: pages) }

    // MARK: - 导出与剪贴板
    
    func exportPageAsMarkdown(_ page: WikiPage) -> URL? {
        let content = """
        ---
        title: \(page.title)
        type: \(page.type.rawValue)
        tags: \(page.tags.joined(separator: ", "))
        ---
        
        # \(page.title)
        
        \(page.content)
        """
        
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
    
    func copyPageToClipboard(_ page: WikiPage) {
        let content = """
        # \(page.title)

        \(page.content)
        """
        WikiPasteboard.string = content
    }

    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) {
        if suggestion.type == "rename", let page = sqliteStore.pages.first(where: { $0.title == suggestion.target }) {
            renamePage(page, to: suggestion.suggestion)
        }
        aiWorkflowStore.removeRefactorSuggestion(id: suggestion.id)
    }
    
    func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) {
        if let index = sqliteStore.pages.firstIndex(where: { $0.id == suggestion.sourcePageID }) {
            var page = sqliteStore.pages[index]
            page.content += "\n\n相关链接: [[\(suggestion.targetTitle)]]"
            updatePage(page, forceDeepScan: false)
        }
        aiWorkflowStore.removePotentialLink(id: suggestion.id)
    }
    
    func renamePage(_ page: WikiPage, to newTitle: String) {
        let oldTitle = page.title
        Task {
            let modifiedPages = await linkService.prepareRename(page: page, to: newTitle, in: pages)
            self.sqliteStore.performBatchWrite { db in
                guard let writer = DatabaseManager.shared.dbWriter else { return }
                let repo = WikiPageStore(dbWriter: writer)
                for p in modifiedPages { try? repo.save(p, using: db) }
            }
            sqliteStore.onLog?(.update, newTitle, "Renamed from \(oldTitle)")
            backupService.markDirty()
        }
    }

    func mountVault(at url: URL) { }
    func resetAllData() { try? clearAllData() }
    func getAllTags() async -> [(tag: String, count: Int)] { await linkService.allTags(in: pages) }

    func renameTag(_ oldTag: String, to newTag: String) {
        sqliteStore.renameTag(oldTag, to: newTag)
    }
    func deleteTag(_ tag: String) {
        sqliteStore.deleteTag(tag)
    }
    
    func bulkDeleteTags(_ tags: Set<String>) {
        sqliteStore.performBatchWrite { [self] _ in
            for tag in tags { self.sqliteStore.deleteTag(tag) }
        }
    }

    func addNewTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        _ = createPage(
            title: Localized.trf("tags.pageTitle", trimmed),
            type: .concept,
            content: Localized.trf("tags.pageContent", trimmed),
            tags: [trimmed]
        )
    }

    // MARK: - 演示数据生成 (封装，避免 View 层直接访问 sqliteStore)
    @discardableResult
    func generateDemoData() -> Int {
        let count = DemoDataGenerator.generate(in: sqliteStore)
        refresh()
        return count
    }

    @discardableResult
    func generateStressTestData() -> Int {
        let count = DemoDataGenerator.generateStressTest(in: sqliteStore)
        refresh()
        return count
    }

    func replaceAllPages(_ pages: [WikiPage]) {
        sqliteStore.replaceAllPages(pages)
        objectWillChange.send()
        refresh()
    }

    /// 开发者选项：清空所有数据（比 clearAllData 更轻量，不触发完整重置流程）
    func clearAllDeveloperData() {
        sqliteStore.clearAllData()
        refresh()
    }

    // MARK: - PDF 操作代理

    func loadPDFDocuments() -> [PDFDocumentInfo] { PDFProcessor.shared.loadDocumentsInfo() }
    func savePDFDocuments(_ docs: [PDFDocumentInfo]) { PDFProcessor.shared.saveDocumentsInfo(docs) }
    func loadPDFDocument(fileName: String) -> PDFKit.PDFDocument? { PDFProcessor.shared.loadPDF(fileName: fileName) }
    func savePDFDocument(data: Data, fileName: String) -> URL? { PDFProcessor.shared.savePDF(data: data, fileName: fileName) }
    func deletePDFDocument(fileName: String) -> Bool { PDFProcessor.shared.deletePDF(fileName: fileName) }
    func extractPDFText(from pdfDoc: PDFKit.PDFDocument, pageRange: Range<Int>? = nil) -> String {
        PDFProcessor.shared.extractText(from: pdfDoc, pageRange: pageRange)
    }

    // MARK: - OCR 操作代理

    func recognizeText(from image: WikiImage) async throws -> String {
        try await OCRProcessor.shared.recognizeText(from: image)
    }
}

// MARK: - CollaborationDelegate 实现
@MainActor
extension KMStore: CollaborationDelegate {
    func applyRemoteUpdate(_ page: WikiPage) {
        updatePage(page, forceDeepScan: false)
    }
}
