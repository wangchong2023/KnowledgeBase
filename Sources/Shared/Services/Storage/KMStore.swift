// KMStore.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的核心状态中心（KMStore），作为应用的数据聚合层与协调中心。
// 它通过“外观模式 (Facade)”整合了底层存储、AI 工作流、链接审计及协作服务，为 UI 层提供统一的数据接口。
// 核心职责包括：
// 1. 状态生命周期管理：通过 @Observable 驱动全局 UI 的响应式刷新，管理 searchStore, settingsStore 等子状态。
// 2. 跨层级操作编排：协调 SQLiteStore 的物理读写与 LinkService 的语义审计，确保数据变更的原子性与一致性。
// 3. 业务指令分发：执行页面创建、撤销重做、全文检索、OCR 识别等高阶指令，并维护操作审计日志。
// 4. 环境适配与兜底：管理 iCloud 同步冲突、演示数据生成及金库安全状态的全局透传。
// 版本: 1.2
// 修改记录:
//   - 2026-05-02: 初始功能实现。
//   - 2026-05-04: 引入子 Store 职责解耦与 DI 容器。
//   - 2026-05-05: 升级全工程文档规范，规范化核心业务指令的文档注释。
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI
@preconcurrency import Combine
@preconcurrency import PDFKit
import Observation

/// 知识管理中心存储：应用的状态大脑与业务指令分发中心。
@MainActor
@Observable
final class KMStore: @preconcurrency GraphDataProvider {
    
    // ── 基础设施依赖 (通过依赖注入获取) ──
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
    var settingsStore: SettingsStore!
    var aiWorkflowStore: AIWorkflowStore!

    /// 当前图谱聚类分析结果
    var clusters: [GraphClusteringService.Cluster] = []
    
    /// 用于手动触发 UI 刷新的标识
    var refreshTrigger = UUID()
    
    /// 交互控制状态
    var showCreateSheet = false
    var showPerfDashboard = false
    
    // ── 协议适配：GraphDataProvider ──
    var isScanningAI: Bool { aiWorkflowStore.isScanningAI }
    var isAIProcessing: Bool { aiWorkflowStore.isProcessingPageAI }
    var isPrivacyModeEnabled: Bool { settingsStore.isPrivacyModeEnabled }
    
    /// 请求图谱重新布局，通过生成新的 refreshTrigger 触发 UI 响应。
    func requestRelayout() {
        refreshTrigger = UUID()
    }
    
    /// 刷新存储状态：重载数据库并更新内存镜像，确保 UI 与磁盘数据一致。
    func refresh() {
        logger.addLog(action: .systemInit, target: "KMStore", details: "Refreshing store. Current pages: \(sqliteStore.pages.count)")
        sqliteStore.reloadFromDisk()
        refreshTrigger = UUID()
        logger.addLog(action: .systemInit, target: "KMStore", details: "Refreshed. New pages count: \(sqliteStore.pages.count)")
    }

    // ── 健康度指标 (由子 Store 驱动) ──
    var healthMetrics: (score: Int, level: LintService.HealthLevel) {
        lintService.calculateHealthMetrics(issues: aiWorkflowStore.lintIssues)
    }
    var lintScore: Int { healthMetrics.score }
    var healthLevel: LintService.HealthLevel { healthMetrics.level }
    
    var lintIssues: [LintIssue] { aiWorkflowStore.lintIssues }
    var brokenLinkCount: Int { lintIssues.filter { $0.type == .brokenLink }.count }
    var orphanPageCount: Int { lintIssues.filter { $0.type == .island || $0.type == .orphan }.count }
    var totalConnectionCount: Int { pages.reduce(0) { $0 + $1.outgoingLinks.count } }
    
    /// 工具项定义
    enum ToolItem: String, CaseIterable, Hashable {
        case index, chat, log, lint, tagCloud, collab, taskCenter, weeklyReport, dashboard, pluginMarket, synthesis
    }

    // MARK: - Coach Marks
    /// 引导说明类型
    enum CoachMarkType: String {
        case graphDiscovery
    }
    /// 待展示的引导项
    var pendingCoachMark: CoachMarkType?
    
    // ── 数据属性 ──
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

    /// 知识增长点：记录特定日期的页面总量
    struct KnowledgeGrowthPoint: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    /// 获取过去 30 天的知识增长曲线
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

    /// 构造函数：执行自我注册与子 Store 初始化
    init() {
        // 核心修复：在任何子初始化之前完成自我注册，防止构造过程中的循环依赖导致注入失效
        ServiceContainer.shared.register(self, for: KMStore.self)
        
        // 子 Store 初始化（使用 @Inject 自动解析依赖）
        self.searchStore = SearchStore()
        self.settingsStore = SettingsStore()
        self.aiWorkflowStore = AIWorkflowStore()
        
        logger.addLog(action: .systemInit, target: "KMStore", details: "init called")
        sqliteStore.onLog = { [weak self] a, t, d in
            self?.addLog(action: a, target: t, details: d)
        }
        seedDefaultContent() 
    }

    /// 填充默认引导内容
    func seedDefaultContent() {
        if pages.isEmpty {
            sqliteStore.seedDefaultContent { [weak self] a, t, d in self?.addLog(action: a, target: t, details: d) }
        }
    }

    // ── 核心业务逻辑 ──

    /// 创建新页面并自动执行初始链接审计。
    /// - Parameters:
    ///   - title: 页面标题，需保持唯一性。
    ///   - type: 页面类型（实体、概念、来源等）。
    ///   - customIcon: 可选的自定义 SF Symbols 图标。
    ///   - content: 初始 Markdown 内容。
    ///   - tags: 初始标签集合。
    ///   - sourceURL: 针对网页摄取的原始链接。
    ///   - rawSnippet: 摄取内容的原始文本片段。
    ///   - forceDeepScan: 是否立即触发 AI 深度扫描流程。
    /// - Returns: 创建成功的 WikiPage 对象。
    @discardableResult
    func createPage(
        title: String,
        type: PageType,
        customIcon: String? = nil,
        content: String = "",
        tags: [String] = [],
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        forceDeepScan: Bool = false
    ) -> WikiPage {
        // 1. 记录撤销快照，确保操作可逆
        undoService.pushSnapshot(pages)
        
        // 2. 调用底层存储引擎执行物理写入
        let page = sqliteStore.createPage(
            title: title,
            type: type,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            forceDeepScan: forceDeepScan
        )
        
        // 3. 标记备份系统为脏，触发后续同步逻辑
        backupService.markDirty()

        // 4. 检查是否触发图谱发现引导（当页面达到一定数量时）
        if totalPages >= 3 && !settingsStore.hasShownGraphCoachMark {
            settingsStore.hasShownGraphCoachMark = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.pendingCoachMark = .graphDiscovery
                }
            }
        }

        // 5. 发布全局事件，通知图谱、搜索等组件更新
        let totalLinks = pages.reduce(0) { $0 + $1.outgoingLinks.count }
        WikiEventBus.shared.publish(.pageCreated(id: page.id, title: page.title, nodeCount: pages.count, linkCount: totalLinks))

        return page
    }

    /// 获取特定页面的反向链接列表（指向该页面的其他页面）。
    func getBacklinks(for id: UUID) -> [WikiPage] { sqliteStore.fetchBacklinksByID(for: id) }
    
    /// 更新页面内容或元数据，支持选择性触发深度扫描。
    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        undoService.pushSnapshot(pages)
        sqliteStore.updatePage(page, forceDeepScan: forceDeepScan)
        backupService.markDirty()
    }

    /// 简单的页面内容保存接口。
    func savePage(_ page: WikiPage) {
        updatePage(page, forceDeepScan: false)
    }

    /// 删除指定页面及其关联的图谱节点。
    func deletePage(_ page: WikiPage) {
        undoService.pushSnapshot(pages)
        sqliteStore.deletePage(page)
    }

    /// 撤销上一次原子操作。
    func undo() { if let prev = undoService.undo(currentPages: pages) { sqliteStore.replaceAllPages(prev) } }
    
    /// 重做上一次被撤销的操作。
    func redo() { if let next = undoService.redo(currentPages: pages) { sqliteStore.replaceAllPages(next) } }

    /// 强制执行关键数据的磁盘持久化并创建即时备份。
    func saveToDisk() {
        logger.saveToDisk()
        backupService.createBackup(pages: pages)
    }
    
    /// 从磁盘全量重载数据，通常用于应用启动或手动恢复。
    func loadFromDisk() { sqliteStore.reloadFromDisk(); logger.loadFromDisk() }
    
    /// 记录业务审计日志。
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval? = nil, startTime: Date? = nil, endTime: Date? = nil, module: String? = "KMStore") { 
        logger.addLog(action: action, target: target, details: details, duration: duration, startTime: startTime, endTime: endTime, module: module) 
    }
    
    /// 清空所有历史审计日志。
    func clearLogs() { logger.clearAllLogs() }
}

// MARK: - KMStore 业务扩展
extension KMStore {
    /// 导入外部 WikiPage 并分配新的唯一 ID。
    func addImportedPage(_ page: WikiPage) {
        var p = page; p.id = UUID()
        sqliteStore.syncRemotePage(p)
    }

    /// 利用 AI 合成服务为当前知识库生成启发式思考问题。
    func generateInsightfulQuestions() async throws -> [String] {
        try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)
    }
    
    /// 同步来自远端（如 iCloud 或协作节点）的页面。
    func insertRemotePage(_ page: WikiPage) {
        sqliteStore.syncRemotePage(page)
    }
    
    /// [危险操作] 彻底清理应用数据，包括数据库文件和本地配置。
    func clearAllData() throws {
        // 核心流程：清理内存 -> 关闭 DB -> 删除物理文件 -> 发布广播 -> 重置标记
        sqliteStore.pages.removeAll()
        undoService.clear()
        
        sqliteStore.close()
        let dbURL = sqliteStore.dbPath
        try? FileManager.default.removeItem(at: dbURL)

        logger.addLog(action: .systemInit, target: "KMStore", details: "Publishing clearAllDataRequested event.")
        WikiEventBus.shared.publish(.clearAllDataRequested)

        UserDefaults.standard.removeObject(forKey: "has_seeded_initial_content")
        UserDefaults.standard.removeObject(forKey: "lastLintIssues")
        UserDefaults.standard.removeObject(forKey: "last_active_page_id")

        WikiEventBus.shared.publish(.pagesCleared)
        logger.addLog(action: .systemInit, target: "System", details: "Global data reset initiated.", module: "KMStore")
        
        refresh()
    }
    
    /// 根据标题查找对应页面（线程安全）。
    func pageByTitle(_ title: String) async -> WikiPage? { await linkService.pageByTitle(title, in: pages) }

    // MARK: - 导出与剪贴板代理
    
    /// 将页面转化为 Markdown 格式临时文件，用于系统级分享。
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
    
    /// 格式化页面内容并复制至剪贴板。
    func copyPageToClipboard(_ page: WikiPage) {
        let content = """
        # \(page.title)

        \(page.content)
        """
        WikiPasteboard.string = content
    }

    /// 应用 AI 结构重构建议（如重命名）。
    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) {
        if suggestion.type == "rename", let page = sqliteStore.pages.first(where: { $0.title == suggestion.target }) {
            renamePage(page, to: suggestion.suggestion)
        }
        aiWorkflowStore.removeRefactorSuggestion(id: suggestion.id)
    }
    
    /// 应用 AI 发现的潜在语义链接。
    func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) {
        if let index = sqliteStore.pages.firstIndex(where: { $0.id == suggestion.sourcePageID }) {
            var page = sqliteStore.pages[index]
            page.content += "\n\n相关链接: [[\(suggestion.targetTitle)]]"
            updatePage(page, forceDeepScan: false)
        }
        aiWorkflowStore.removePotentialLink(id: suggestion.id)
    }
    
    /// 重命名页面并协调更新所有双向链接引用。
    func renamePage(_ page: WikiPage, to newTitle: String) {
        let oldTitle = page.title
        Task {
            // 核心流程：预计算链接变更 -> 批量物理写入 -> 标记备份
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

    /// 重置全库数据（Facade 接口）。
    func resetAllData() { try? clearAllData() }
    
    /// 获取全库标签及其关联页面计数。
    func getAllTags() async -> [(tag: String, count: Int)] { await linkService.allTags(in: pages) }

    /// 在全库范围内重命名标签。
    func renameTag(_ oldTag: String, to newTag: String) {
        sqliteStore.renameTag(oldTag, to: newTag)
    }
    
    /// 物理删除特定标签引用。
    func deleteTag(_ tag: String) {
        sqliteStore.deleteTag(tag)
    }
    
    /// 批量清理选中的标签集合。
    func bulkDeleteTags(_ tags: Set<String>) {
        sqliteStore.performBatchWrite { [self] _ in
            for tag in tags { self.sqliteStore.deleteTag(tag) }
        }
    }

    /// 创建一个包含特定标签的概念页面。
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

    // MARK: - 演示数据生成

    /// 生成标准演示数据集，用于快速体验应用功能。
    @discardableResult
    func generateDemoData() -> Int {
        let count = DemoDataGenerator.generate(in: sqliteStore)
        refresh()
        return count
    }

    /// 生成大规模测试数据，用于验证图谱与搜索性能。
    @discardableResult
    func generateStressTestData() -> Int {
        let count = DemoDataGenerator.generateStressTest(in: sqliteStore)
        refresh()
        return count
    }

    /// 替换内存中所有的页面（用于回滚操作）
    func replaceAllPages(_ pages: [WikiPage]) {
        sqliteStore.replaceAllPages(pages)
        objectWillChange.send()
        refresh()
    }

    /// 开发者选项：清空数据
    func clearAllDeveloperData() {
        try? clearAllData()
    }

    // MARK: - PDF 操作代理 (Facade 转办)

    func loadPDFDocuments() -> [PDFDocumentInfo] { PDFProcessor.shared.loadDocumentsInfo() }
    func savePDFDocuments(_ docs: [PDFDocumentInfo]) { PDFProcessor.shared.saveDocumentsInfo(docs) }
    func loadPDFDocument(fileName: String) -> PDFKit.PDFDocument? { PDFProcessor.shared.loadPDF(fileName: fileName) }
    func savePDFDocument(data: Data, fileName: String) -> URL? { PDFProcessor.shared.savePDF(data: data, fileName: fileName) }
    func deletePDFDocument(fileName: String) -> Bool { PDFProcessor.shared.deletePDF(fileName: fileName) }
    func extractPDFText(from pdfDoc: PDFKit.PDFDocument, pageRange: Range<Int>? = nil) -> String {
        PDFProcessor.shared.extractText(from: pdfDoc, pageRange: pageRange)
    }

    // MARK: - OCR 操作代理 (Facade 转办)

    /// 对图像执行文本识别
    func recognizeText(from image: WikiImage) async throws -> String {
        try await OCRProcessor.shared.recognizeText(from: image)
    }

    /// 导入整个文件夹的内容
    func ingestFolder(at url: URL) {
        _ = ingestService.ingestFolder(at: url, pageStore: self)
        refresh()
    }
}

// MARK: - CollaborationDelegate 实现
@MainActor
extension KMStore: CollaborationDelegate {
    func applyRemoteUpdate(_ page: WikiPage) {
        updatePage(page, forceDeepScan: false)
    }
}
// MARK: - AnyPageStore 协议实现
@MainActor
extension KMStore: AnyPageStore {
    func createPage(title: String, type: PageType, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, forceDeepScan: Bool) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags, sourceURL: sourceURL, rawSnippet: rawSnippet, forceDeepScan: forceDeepScan)
    }
}
