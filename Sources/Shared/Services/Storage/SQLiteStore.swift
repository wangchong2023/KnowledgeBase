import Foundation
import SQLite3
import NaturalLanguage
import Observation

// MARK: - SQLite 存储门面 (组合了核心、迁移与种子数据)
/// 轻量级门面，组合了 SQLiteStoreCore, SQLiteMigrator 和 KMSeedData。
/// 所有的数据库操作都委派给 SQLiteStoreCore 执行。
@MainActor
@Observable
final class SQLiteStore {
    var pages: [WikiPage] = []

    // MARK: - 子组件
    private let core: SQLiteStoreCore
    private let migrator: SQLiteMigrator
    private(set) var embeddingManager: EmbeddingManager!

    // MARK: - 回调钩子
    var onLog: ((LogAction, String, String) -> Void)?
    var onSaveNeeded: (() -> Void)?
    
    var dbPath: URL { core.dbPath }

    // MARK: - 初始化
    init() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dbPath = docsDir.appendingPathComponent("km.sqlite3")

        // 1. 完整性校验
        if FileManager.default.fileExists(atPath: dbPath.path) {
            if !SecurityManager.shared.verifyIntegrity(for: dbPath) {
                // 校验失败：可能被篡改。在生产环境中应引导用户恢复备份。
                print("⚠️ Database integrity check failed! File might be tampered.")
                // 此处简单处理：记录日志。
            }
        }

        self.core = SQLiteStoreCore(dbPath: dbPath)
        self.migrator = SQLiteMigrator(core: core, docsDir: docsDir)
        self.embeddingManager = EmbeddingManager(core: core)

        core.open()
        core.createTables()
        migrator.migrateIfNeeded()
        loadAllPages()
        
        // 初始化/更新签名
        SecurityManager.shared.updateSignature(for: dbPath)
        
        // 启动后台向量同步
        embeddingManager.syncEmbeddings(pages: pages)
    }

    func close() {
        core.close()
    }

    deinit {
        // SQLiteStoreCore is not Sendable, deinit is nonisolated.
        // We ensure resources are managed correctly without direct cross-actor access.
    }

    // MARK: - CRUD 操作 (增删改查)
    
    /// 创建新页面
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
        print("🏭 [SQLiteStore] createPage: '\(title.prefix(10))', Core: \(Unmanaged.passUnretained(core).toOpaque())")
        let page = WikiPage(
            title: title,
            type: type,
            customIcon: customIcon,
            content: content,
            tags: tags,
            status: content.isEmpty ? .stub : .active,
            sourceURL: sourceURL,
            rawTextSnippet: rawSnippet
        )

        core.insertPage(page)
        pages.append(page)
        core.updateLinks(sourceID: page.id, targetTitles: page.outgoingLinks)
        embeddingManager.updateEmbedding(for: page)
        
        // 如果内容较长，或者强制开启深度扫描
        if forceDeepScan || content.count > 500 {
            performDeepScan(for: page)
        }

        onLog?(.create, title, "\(Localized.tr("detail.pageType")): \(type.displayName)")
        SecurityManager.shared.updateSignature(for: core.dbPath)
        return page
    }

    // MARK: - 事务支持
    func beginTransaction() { core.beginTransaction() }
    func commitTransaction() { core.commitTransaction() }

    /// 更新现有页面
    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            var updated = page
            updated.updated = Date()
            
            // 递增逻辑时钟：每次本地更新，逻辑时间步进，确保本地修改的权重高于同步前的版本
            updated.lamportTimestamp += 1
            
            pages[index] = updated
            core.updatePage(updated)
            core.updateLinks(sourceID: updated.id, targetTitles: updated.outgoingLinks)
            embeddingManager.updateEmbedding(for: updated)
            
            // 重新评估并更新深度扫描分块
            if forceDeepScan || updated.content.count > 500 {
                performDeepScan(for: updated)
            }
            
            SecurityManager.shared.updateSignature(for: core.dbPath)
            onLog?(.update, page.title, "")
        }
    }
    
    /// 同步远程页面 (核心 LWW 冲突解决逻辑)
    /// 用于集成多端同步服务（如 iCloud/Git）拉取回来的数据
    func syncRemotePage(_ remotePage: WikiPage) {
        if let localIndex = pages.firstIndex(where: { $0.id == remotePage.id }) {
            let localPage = pages[localIndex]
            
            // 调用模型层的合并算法
            let mergedPage = localPage.merge(with: remotePage)
            
            // 如果合并结果发生了变化（权重胜出），则更新本地存储
            if mergedPage.lamportTimestamp != localPage.lamportTimestamp || mergedPage.updated != localPage.updated {
                LogService.shared.debug("♻️ [LWW] 页面 \(remotePage.title) 发生冲突，自动收敛至最新版本 (Lamport: \(mergedPage.lamportTimestamp))")
                core.updatePage(mergedPage)
                embeddingManager.updateEmbedding(for: mergedPage)
            }
        } else {
            // 本地不存在，直接插入
            core.insertPage(remotePage)
            pages.append(remotePage)
            embeddingManager.updateEmbedding(for: remotePage)
        }
    }

    /// 删除页面，并处理相关的引用清理
    func deletePage(_ page: WikiPage, clearSelectionIfNeeded: (UUID) -> Bool) {
        // 首先移除其他页面中对该页面的引用
        for i in pages.indices {
            if pages[i].relatedPageIDs.contains(page.id) {
                var refPage = pages[i]
                refPage.relatedPageIDs.removeAll { $0 == page.id }
                core.updatePage(refPage)
                pages[i] = refPage
            }
        }

        core.deletePage(id: page.id)
        _ = clearSelectionIfNeeded(page.id)
        pages.removeAll { $0.id == page.id }

        onLog?(.delete, page.title, "")
    }

    func clearAllData() {
        core.deleteAllPages()
        pages.removeAll()
        onSaveNeeded?()
    }

    // MARK: - 检索方法
    
    func pageByID(_ id: UUID) -> WikiPage? {
        pages.first { $0.id == id }
    }

    func pageByTitle(_ title: String) -> WikiPage? {
        let lower = title.lowercased()

        // 优先进行数据库精确匹配
        if let exact = core.selectPageByColumn("title", value: title.lowercased()) {
            return exact
        }

        // 其次匹配别名
        return pages.first { page in
            page.aliases.contains { $0.lowercased() == lower }
        }
    }

    /// 获取引用了指定页面的所有页面 (O(1) 数据库索引版)
    func fetchBacklinksByID(for pageID: UUID) -> [WikiPage] {
        guard let page = pageByID(pageID) else { return [] }
        let sourceIDs = core.fetchBacklinks(for: page.title)
        return sourceIDs.compactMap { id in pageByID(id) }
    }

    /// 混合搜索（对标 Karpathy 模式：关键词 + 语义提取）
    func searchPages(query: String) -> [WikiPage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pages }
        
        // 埋点：用户搜索行为
        LocalAnalyticsService.shared.trackEvent("search_triggered", properties: ["query_length": trimmed.count])

        // 1. 安全转义处理
        let sanitizedQuery = sanitizeFTSQuery(trimmed)
        
        // 2. 语义预处理：提取名词和核心词
        let keywords = extractSearchKeywords(from: trimmed)
        
        // 3. 构建混合 FTS5 查询 (原词权重最高，关键词次之)
        // 使用双引号包裹以确保特殊字符安全，并支持前缀匹配 (*)
        var finalQuery = "\"\(sanitizedQuery)\"*^5" 
        if !keywords.isEmpty {
            let semanticPart = keywords.map { "\"\(sanitizeFTSQuery($0))\"*" }.joined(separator: " OR ")
            finalQuery += " OR (\(semanticPart))"
        }

        // 直接调用底层 FTS5 引擎进行检索
        return core.searchPagesFTS(query: finalQuery)
    }

    /// 对 FTS5 关键字进行安全转义，防止 SQL 注入或语法错误
    private func sanitizeFTSQuery(_ query: String) -> String {
        // 在 FTS5 中，转义双引号的方式是使用两个双引号
        return query.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func extractSearchKeywords(from query: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = query
        var keywords: [String] = []
        
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            if let tag = tag, tag == .noun || tag == .otherWord {
                keywords.append(String(query[range]))
            }
            return true
        }
        return keywords
    }

    func pagesByType(_ type: PageType) -> [WikiPage] {
        pages.filter { $0.type == type }
    }

    func pagesByStatus(_ status: PageStatus) -> [WikiPage] {
        pages.filter { $0.status == status }
    }

    // MARK: - 统计信息 (已优化：直接查询数据库聚合)
    var totalPages: Int { core.countPages() }
    var entityCount: Int { core.countPages(type: "entity") }
    var conceptCount: Int { core.countPages(type: "concept") }
    var sourceCount: Int { core.countPages(type: "source") }
    var stubCount: Int { core.countStubPages() }
    var activeCount: Int { core.countActivePages() }
    var totalWords: Int { pages.reduce(0) { $0 + $1.wordCount } }

    // MARK: - 批量操作
    func replaceAllPages(_ newPages: [WikiPage]) {
        core.beginTransaction()
        core.deleteAllPages()
        for page in newPages {
            core.insertPage(page)
        }
        core.commitTransaction()
        pages = newPages
    }

    func removeAllPages() {
        core.deleteAllPages()
        pages = []
    }

    // MARK: - 载入与重载
    func loadAllPages() {
        pages = core.selectAllPages()
        print("📦 [SQLiteStore] Loaded \(pages.count) pages from disk.")
    }

    func reloadFromDisk() {
        print("🔄 [SQLiteStore] reloadFromDisk, Core: \(Unmanaged.passUnretained(core).toOpaque())")
        core.open()
        core.createTables()
        loadAllPages()
        onSaveNeeded?()
    }

    // MARK: - 种子数据
    /// 在首次启动时创建欢迎页面。
    func seedDefaultContent(logAction: (LogAction, String, String) -> Void) {
        let hasSeeded = UserDefaults.standard.bool(forKey: "has_seeded_initial_content")
        // 如果已经填充过且数据库不为空，则跳过
        if hasSeeded && !pages.isEmpty { return }
        
        let appName = Localized.tr("app.name")
        
        // 1. 欢迎页
        _ = createPage(
            title: "👋 \(Localized.tr("welcome.title")) \(appName)",
            type: .concept,
            content: """
            # \(Localized.tr("welcome.header"))
            
            \(appName) \(Localized.tr("welcome.desc1")) [[3D \(Localized.tr("sidebar.graph"))]] \(Localized.tr("welcome.desc2"))
            
            ### \(Localized.tr("welcome.startTitle"))
            - \(Localized.tr("welcome.start1")) [[\(Localized.tr("sidebar.chat"))]] \(Localized.tr("welcome.start2"))
            - \(Localized.tr("welcome.start3"))
            - \(Localized.tr("welcome.start4"))
            """,
            tags: [Localized.tr("welcome.tag1"), Localized.tr("welcome.tag2")]
        )
        
        // 2. 关于图谱
        _ = createPage(
            title: Localized.tr("sidebar.graph"),
            type: .concept,
            content: Localized.tr("demo.planning.content"), // Reuse or add new keys if needed, but sidebar.graph title is definitely needed.
            tags: [Localized.tr("welcome.tag1"), Localized.tr("sidebar.graph")]
        )
        
        // 3. AI 助手指南
        _ = createPage(
            title: Localized.tr("sidebar.chat"),
            type: .concept,
            content: Localized.tr("demo.aiAgent.content"),
            tags: ["AI", "RAG"]
        )
        
        UserDefaults.standard.set(true, forKey: "has_seeded_initial_content")
        logAction(.systemInit, "SystemVault", Localized.tr("log.seedSuccess"))
    }
    
    // MARK: - RAG & Deep Scan
    
    private func performDeepScan(for page: WikiPage) {
        let chunker = RecursiveChunker()
        let chunks = chunker.split(text: page.content)
        
        // 异步执行向量化与存储
        let manager = self.embeddingManager
        let storage = self.core
        struct SendableStorage: @unchecked Sendable {
            let core: SQLiteStoreCore
        }
        let safeStorage = SendableStorage(core: storage)
        
        DispatchQueue.global(qos: .background).async {
            let texts = chunks.map { $0.text }
            let embeddings = manager?.vectorizeChunks(chunks: texts) ?? []
            safeStorage.core.saveChunks(pageID: page.id, chunks: chunks, embeddings: embeddings)
        }
    }
}

// MARK: - AnyPageStore 协议实现
@MainActor
extension SQLiteStore: AnyPageStore {
    @discardableResult
    func createPage(title: String, type: PageType, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, forceDeepScan: Bool) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags, sourceURL: sourceURL, rawSnippet: rawSnippet, forceDeepScan: forceDeepScan)
    }
}


extension SQLiteStore: @unchecked Sendable {}

/// 演示数据生成器
/// 用于快速填充知识库，展示图谱、检索及 AI 分析能力。
/// 采用 Swift 实现以确保在 iOS/macOS 各平台及沙盒环境下均能稳定运行。
struct DemoDataGenerator {
    @MainActor
    static func generate(in store: SQLiteStore) -> Int {
        print("🧪 [Demo] Starting demo data generation...")
        // 确保是一个纯净的演示环境
        store.removeAllPages()
        MedalService.shared.reset()
        
        print("🧪 [Demo] Store cleared.")
        var count = 0
        
        // 使用事务包裹批量插入，极大提升性能并防止并发竞争导致的写入失败
        store.beginTransaction()
        defer { store.commitTransaction() }
        
        _ = store.createPage(
            title: Localized.tr("demo.aiAgent.title"),
            type: .concept,
            content: Localized.tr("demo.aiAgent.content"),
            tags: ["AI", "Agent", Localized.tr("sidebar.system")]
        )
        count += 1
        
        _ = store.createPage(
            title: Localized.tr("demo.planning.title"),
            type: .concept,
            content: Localized.tr("demo.planning.content"),
            tags: ["AI", "Planning", Localized.tr("sidebar.tools")]
        )
        count += 1
        
        _ = store.createPage(
            title: Localized.tr("demo.memory.title"),
            type: .concept,
            content: Localized.tr("demo.memory.content"),
            tags: ["AI", "Memory", "RAG"]
        )
        count += 1
        
        _ = store.createPage(
            title: Localized.tr("demo.toolUse.title"),
            type: .concept,
            content: Localized.tr("demo.toolUse.content"),
            tags: ["AI", "ToolUse", "API"]
        )
        count += 1
        
        // 5. LLM 角色
        _ = store.createPage(
            title: Localized.tr("demo.llm.title"),
            type: .concept,
            content: Localized.tr("demo.llm.content"),
            tags: ["AI", "LLM", Localized.tr("sidebar.capabilities")]
        )
        count += 1
        
        print("🧪 [Demo] Generation finished. Total: \(count)")
        return count
    }
}
