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

    // MARK: - Synthesis Management
    struct SynthesisDocument: Codable, Identifiable {
        let id: UUID
        let type: SynthesisType
        let name: String
        let content: String
        let createdAt: Date
    }

    enum SynthesisType: String, CaseIterable, Codable, Identifiable {
        case mindmap, slides, quiz, report
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .mindmap: return Localized.tr("prompt.expert.mindmap.title")
            case .slides: return Localized.tr("prompt.expert.slides.title")
            case .quiz: return Localized.tr("prompt.expert.quiz.title")
            case .report: return Localized.tr("prompt.expert.report.title")
            }
        }
        
        var icon: String {
            switch self {
            case .mindmap: return "circle.hexagongrid.fill"
            case .slides: return "play.rectangle"
            case .quiz: return "checklist.checked"
            case .report: return "doc.text.magnifyingglass"
            }
        }

        /// 获取对应的文件格式图标
        var formatIcon: String {
            switch self {
            case .mindmap: return "doc.plaintext"      // Markdown
            case .slides: return "play.rectangle.fill" // PPT/Slides
            case .quiz: return "checklist.checked"    // Quiz
            case .report: return "doc.richtext.fill"   // PDF/Report
            }
        }
        
        /// 获取对应的格式颜色
        var formatColor: Color {
            switch self {
            case .mindmap: return .blue
            case .slides: return .orange
            case .quiz: return .green
            case .report: return .red
            }
        }
    }

    enum SynthesisStatus: Equatable {
        case idle
        case generating
        case completed
        case error(String)
        
        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    @ObservationIgnored private var _synthesisResults: [SynthesisType: SynthesisDocument] = [:]
    var synthesisResults: [SynthesisType: SynthesisDocument] {
        get { access(keyPath: \.synthesisResults); return _synthesisResults }
        set { withMutation(keyPath: \.synthesisResults) { _synthesisResults = newValue } }
    }

    var synthesisStates: [SynthesisType: SynthesisStatus] = {
        var states: [SynthesisType: SynthesisStatus] = [:]
        for type in SynthesisType.allCases { states[type] = .idle }
        return states
    }()
    
    func loadSynthesisResults() {
        for type in SynthesisType.allCases {
            let key = "synthesis_doc_\(type.rawValue)"
            if let data = UserDefaults.standard.data(forKey: key),
               let doc = try? JSONDecoder().decode(SynthesisDocument.self, from: data) {
                _synthesisResults[type] = doc
                synthesisStates[type] = .completed
            }
        }
    }

    func saveSynthesisResult(type: SynthesisType, content: String) {
        let name = "\(type.title) - \(formatDateShort(Date()))"
        let doc = SynthesisDocument(id: UUID(), type: type, name: name, content: content, createdAt: Date())
        _synthesisResults[type] = doc
        synthesisStates[type] = .completed
        
        if let data = try? JSONEncoder().encode(doc) {
            UserDefaults.standard.set(data, forKey: "synthesis_doc_\(type.rawValue)")
        }
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
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

    init() { 
        seedDefaultContent() 
        loadSynthesisResults()
    }

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

    func saveToDisk() { 
        logService.saveToDisk(); 
        backupService.createBackup(pages: pages) 
        // 触发成就检查
        let totalLinks = pages.reduce(0) { $0 + $1.outgoingLinks.count }
        MedalService.shared.checkAchievements(nodeCount: pages.count, linkCount: totalLinks)
    }
    func loadFromDisk() { sqliteStore.reloadFromDisk(); logService.loadFromDisk() }
    
    func addLog(action: String, target: String, details: String) { logService.addLog(action: action, target: target, details: details) }
}

// MARK: - 奖章系统服务
/// 负责追踪用户成就并触发奖励弹窗
@MainActor
final class MedalService: ObservableObject {
    static let shared = MedalService()
    
    struct Medal: Identifiable, Codable, Equatable {
        let id: String
        let titleKey: String
        let descKey: String
        let icon: String
        let colorHex: String
        let threshold: Int
        let category: Category
        
        enum Category: String, Codable {
            case accumulation, connection, explore
        }
    }
    
    @Published var newlyEarnedMedal: Medal?
    @Published var earnedMedalIDs: Set<String> = []
    
    let allMedals: [Medal] = [
        Medal(id: "first_page", titleKey: "medal.first_page.title", descKey: "medal.first_page.desc", icon: "sparkles", colorHex: "#FFD700", threshold: 1, category: .explore),
        Medal(id: "nodes_5", titleKey: "medal.nodes_5.title", descKey: "medal.nodes_5.desc", icon: "doc.badge.plus", colorHex: "#4FACFE", threshold: 5, category: .accumulation),
        Medal(id: "nodes_10", titleKey: "medal.nodes_10.title", descKey: "medal.nodes_10.desc", icon: "books.vertical.fill", colorHex: "#00F2FE", threshold: 10, category: .accumulation),
        Medal(id: "nodes_100", titleKey: "medal.nodes_100.title", descKey: "medal.nodes_100.desc", icon: "archivebox.fill", colorHex: "#A8EDEA", threshold: 100, category: .accumulation),
        Medal(id: "links_5", titleKey: "medal.links_5.title", descKey: "medal.links_5.desc", icon: "link", colorHex: "#F093FB", threshold: 5, category: .connection),
        Medal(id: "links_10", titleKey: "medal.links_10.title", descKey: "medal.links_10.desc", icon: "link.badge.plus", colorHex: "#F5576C", threshold: 10, category: .connection),
        Medal(id: "links_100", titleKey: "medal.links_100.title", descKey: "medal.links_100.desc", icon: "hubball.fill", colorHex: "#8EC5FC", threshold: 100, category: .connection)
    ]
    
    private init() { loadEarnedMedals() }
    
    func checkAchievements(nodeCount: Int, linkCount: Int) {
        for medal in allMedals {
            if earnedMedalIDs.contains(medal.id) { continue }
            var isEarned = false
            switch medal.category {
            case .explore where medal.id == "first_page": isEarned = nodeCount >= 1
            case .accumulation: isEarned = nodeCount >= medal.threshold
            case .connection: isEarned = linkCount >= medal.threshold
            default: break
            }
            if isEarned {
                earnedMedalIDs.insert(medal.id)
                newlyEarnedMedal = medal
                saveEarnedMedals()
                HapticManager.shared.trigger(.success)
            }
        }
    }
    
    private func saveEarnedMedals() {
        if let data = try? JSONEncoder().encode(earnedMedalIDs) { UserDefaults.standard.set(data, forKey: "earned_medals") }
    }
    private func loadEarnedMedals() {
        if let data = UserDefaults.standard.data(forKey: "earned_medals"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) { earnedMedalIDs = decoded }
    }
}

// MARK: - KMStore 补充方法（DeepLink、数据操作等）
extension KMStore {
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
        let taskID = TaskCenter.shared.addTask(type: .healthCheck, name: Localized.tr("sidebar.healthCheck"), target: "System")
        Task {
            let issues = await lintService.runLint(pages: pages, linkService: linkService)
            await MainActor.run {
                self.lintIssues = issues
                self.lastLintDate = Date()
                TaskCenter.shared.updateTask(taskID, status: .completed)
            }
        }
    }
    
    func runAIScan() async {
        guard llmService.isEnabled else { 
            logService.addLog(action: Localized.tr("log.action.aiscan.skipped"), target: "System", details: "LLM service disabled")
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
            logService.addLog(action: Localized.tr("log.action.aiscan.failed"), target: "System", details: error.localizedDescription)
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
    
    func performSynthesis(type: SynthesisType) {
        guard llmService.isEnabled else { return }
        guard synthesisStates[type] != .generating else { return }
        
        synthesisStates[type] = .generating
        let taskID = TaskCenter.shared.addTask(type: .synthesis, name: type.title, target: Localized.tr("sidebar.synthesis"))
        
        let combinedContent = pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        
        Task {
            do {
                let content: String
                switch type {
                case .mindmap:
                    content = try await AISynthesisService.shared.generateMindMap(content: combinedContent)
                case .slides:
                    content = try await AISynthesisService.shared.generatePresentation(content: combinedContent)
                case .quiz:
                    content = try await AISynthesisService.shared.generateQuiz(content: combinedContent)
                case .report:
                    content = try await AISynthesisService.shared.generateReport(content: combinedContent)
                }
                
                await MainActor.run {
                    self.saveSynthesisResult(type: type, content: content)
                    TaskCenter.shared.updateTask(taskID, status: .completed)
                }
            } catch {
                await MainActor.run {
                    self.synthesisStates[type] = .error(error.localizedDescription)
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                }
            }
        }
    }
}
