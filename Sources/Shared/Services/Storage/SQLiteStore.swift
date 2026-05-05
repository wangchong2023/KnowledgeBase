// SQLiteStore.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的中央存储门面（SQLiteStore），作为整个应用层与底层持久化层之间的核心桥梁与协调器。
// 该类通过高度聚合的设计模式，整合了页面管理、向量索引与全文搜索能力，核心功能点如下：
// 1. 响应式数据流管理：基于 GRDB 的 ValueObservation 机制，实现了数据库状态与 UI 内存模型（pages）的自动同步与实时响应。
// 2. 知识自动化治理（RAG）：内置 Deep Scan 机制，配合 TextChunkerProcessor 与 EmbeddingManager 实现资料的自动化分块与向量化同步。
// 3. 冲突解决与同步：集成了 LWW (Last Write Wins) 合并算法，确保多端同步或并行写入时的页面元数据一致性。
// 4. 数据安全与完整性：提供了基于签名校验（SecurityManager）的数据库完整性检查，并管理旧版本 JSON 数据的平滑迁移逻辑。
// 5. 多维度检索调度：提供了结合 FTS5 全文搜索、别名匹配（Aliases）及反向链接追踪的综合检索接口，支撑知识的高效触达。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，详细描述存储门面的编排职责与 RAG 集成逻辑
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import GRDB
import NaturalLanguage
import Observation

// MARK: - SQLite 存储门面
/// 现代化存储门面，组合了 WikiPageStore 和 EmbeddingManager。
/// 所有的数据库操作都通过 GRDB 仓库层执行，确保类型安全与高并发。
@MainActor
@Observable
final class SQLiteStore {
    var pages: [WikiPage] = []

    // MARK: - 子组件
    private let repository: WikiPageStore
    private(set) var embeddingManager: EmbeddingManager!
    // 使用 @ObservationIgnored 并标记为 nonisolated(unsafe) 以允许在 deinit 中安全取消
    @ObservationIgnored
    private nonisolated(unsafe) var observationTask: Task<Void, Never>?
    private var currentTransaction: DatabaseWriter? // 临时持有用于事务

    // MARK: - 回调钩子
    var onLog: ((LogAction, String, String) -> Void)?
    var onSaveNeeded: (() -> Void)?
    
    // MARK: - 动态计算属性
    
    /// 获取当前活跃数据库的物理路径
    /// - Returns: 数据库文件的 URL 路径
    var dbPath: URL { 
        // 核心修复：通过 dbWriter 协议安全获取路径，避免在 DatabaseQueue 模式下强行解包 dbPool
        URL(fileURLWithPath: DatabaseManager.shared.dbWriter?.path ?? "") 
    }

    // MARK: - 初始化
    /// 初始化存储门面，执行数据库连接、完整性校验、迁移及观察者启动
    /// - Parameter providedURL: 可选的自定义数据库路径，若为 nil 则使用默认路径
    init(dbURL providedURL: URL? = nil) {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dbPath = providedURL ?? docsDir.appendingPathComponent("km.sqlite3")

        // 1. 完整性校验（仅对物理文件且非内存数据库执行，测试环境跳过）
        if !DatabaseManager.shared.isInTesting && dbPath.scheme == "file" && FileManager.default.fileExists(atPath: dbPath.path) {
            if !SecurityManager.shared.verifyIntegrity(for: dbPath) {
                Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Database integrity check failed! File might be tampered.")
            }
        }
        do {
            // 2. 初始化 GRDB 管理器
            try DatabaseManager.shared.setup(at: dbPath)
            guard let writer = DatabaseManager.shared.dbWriter else {
                throw DatabaseError.initializationFailed
            }
            self.repository = WikiPageStore(dbWriter: writer)
            self.embeddingManager = EmbeddingManager(repository: repository)
            
            // 3. 执行旧数据迁移 (如果存在 JSON)
            migrateLegacyJSONIfNeeded(docsDir: docsDir)
            
            // 4. 启动响应式观察 (ValueObservation)
            setupObservation(with: DatabaseManager.shared.dbWriter)
        } catch {
            fatalError("❌ [SQLiteStore] Failed to initialize Database: \(error)")
        }

        // 初始化/更新签名 (测试环境跳过)
        if !DatabaseManager.shared.isInTesting {
            SecurityManager.shared.updateSignature(for: dbPath)
        }
        
        // 启动后台向量同步
        embeddingManager.syncEmbeddings(pages: pages)
    }

    /// 处理从旧版 JSON 文件到 SQLite 的数据平滑迁移
    /// - Parameter docsDir: 文档目录路径
    private func migrateLegacyJSONIfNeeded(docsDir: URL) {
        let jsonURL = docsDir.appendingPathComponent("wikicraft_pages.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }
        guard (try? repository.count()) == 0 else { return }
        
        Logger.shared.addLog(action: .systemInit, target: "SQLiteStore", details: "Migrating from legacy JSON...")
        do {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyPages = try decoder.decode([WikiPage].self, from: data)
            
            for page in legacyPages {
                try repository.save(page)
            }
            
            try? FileManager.default.moveItem(at: jsonURL, to: jsonURL.appendingPathExtension("migrated"))
            Logger.shared.addLog(action: .systemInit, target: "SQLiteStore", details: "Migration finished: \(legacyPages.count) pages.")
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Migration failed: \(error.localizedDescription)")
        }
    }

    /// 开启数据库记录观察任务，监听全表变更并自动同步至内存 pages
    /// - Parameter dbWriter: 数据库写入器实例
    private func setupObservation(with dbWriter: (any DatabaseWriter)?) {
        guard let dbWriter = dbWriter else { return }
        observationTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.startObservation(on: dbWriter)
            } catch {
                Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "ValueObservation failed: \(error.localizedDescription)")
            }
        }
    }

    /// 执行具体的 ValueObservation 循环，保持数据一致性与 RAG 同步
    /// - Parameter reader: 数据库读取器实例
    private func startObservation(on reader: some DatabaseReader) async throws {
        let observation = ValueObservation.tracking { db in
            try WikiPage.order(Column("updated").desc).fetchAll(db)
        }
        
        for try await latestPages in observation.values(in: reader) {
            await MainActor.run {
                self.pages = latestPages
                self.embeddingManager.syncEmbeddings(pages: latestPages)
            }
        }
    }

    /// 关闭当前观察任务，用于重置数据库或资源清理
    func close() {
        observationTask?.cancel()
        observationTask = nil
    }

    /// 彻底重置数据库物理文件并重新初始化观察流。
    /// 彻底重置数据库物理文件并重新初始化观察流
    /// - Throws: 移除文件或重新 Setup 过程中的错误
    func resetDatabase() throws {
        // 1. 停止当前观察并关闭连接
        close()
        let path = dbPath
        DatabaseManager.shared.reset()
        
        // 2. 物理删除文件
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        
        // 3. 重新执行 Setup
        try DatabaseManager.shared.setup(at: path)
        
        // 4. 重新启动观察
        setupObservation(with: DatabaseManager.shared.dbWriter)
        
        Logger.shared.addLog(action: .systemInit, target: "SQLiteStore", details: "Database reset and observation restarted.")
    }

    deinit {
        // deinit 是 nonisolated 上下文，直接操作存储属性
        observationTask?.cancel()
    }

    // MARK: - CRUD 操作 (增删改查)
    
    /// 创建并保存新页面，同步处理链接提取与向量化
    /// - Parameters:
    ///   - title: 页面标题
    ///   - type: 页面类型
    ///   - customIcon: 自定义图标
    ///   - content: 页面 Markdown 内容
    ///   - tags: 标签列表
    ///   - sourceURL: 来源 URL
    ///   - rawSnippet: 原始片段
    ///   - forceDeepScan: 是否强制执行深度分块扫描
    /// - Returns: 返回创建成功的 WikiPage 实例
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

        do {
            try repository.save(page)
            // pages.append(page) // <- 移除：由 ValueObservation 自动同步
            try repository.saveLinks(sourceID: page.id, targetTitles: page.outgoingLinks)
            embeddingManager.updateEmbedding(for: page)
            
            if forceDeepScan || content.count > 500 {
                performDeepScan(for: page)
            }

            onLog?(.create, title, "\(Localized.tr("detail.pageType")): \(type.displayName)")
            SecurityManager.shared.updateSignature(for: dbPath)
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Create page failed: \(error.localizedDescription)")
        }
        return page
    }

    /// 执行数据库写入事务，确保批量操作的原子性
    /// - Parameter updates: 闭包，接收 Database 实例并执行操作
    func performBatchWrite(_ updates: @escaping (Database) throws -> Void) {
        do {
            try DatabaseManager.shared.dbWriter?.write(updates)
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Batch write failed: \(error.localizedDescription)")
        }
    }

    /// 更新现有页面元数据，同步更新链接与向量，并根据内容长度触发 Deep Scan
    /// - Parameters:
    ///   - page: 待更新的页面对象
    ///   - forceDeepScan: 是否强制重新分块向量化
    func updatePage(_ page: WikiPage, forceDeepScan: Bool) {
        if pages.contains(where: { $0.id == page.id }) {
            var updated = page
            updated.updated = Date()
            updated.lamportTimestamp += 1

            do {
                try repository.save(updated)
                // pages[index] = updated // <- 移除：由 ValueObservation 自动同步
                try repository.saveLinks(sourceID: updated.id, targetTitles: updated.outgoingLinks)
                embeddingManager.updateEmbedding(for: updated)

                if forceDeepScan || updated.content.count > 500 {
                    performDeepScan(for: updated)
                }

                SecurityManager.shared.updateSignature(for: dbPath)
                onLog?(.update, page.title, "")
            } catch {
                Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Update page failed: \(error.localizedDescription)")
            }
        }
    }

    /// 同步远程页面，应用 Lamport Timestamp 的 LWW 合并策略解决多端冲突
    /// - Parameter remotePage: 来自外部（如 iCloud）的页面对象
    func syncRemotePage(_ remotePage: WikiPage) {
        if let localIndex = pages.firstIndex(where: { $0.id == remotePage.id }) {
            let localPage = pages[localIndex]
            let mergedPage = localPage.merge(with: remotePage)

            if mergedPage.lamportTimestamp != localPage.lamportTimestamp || mergedPage.updated != localPage.updated {
                Logger.shared.debug("♻️ [LWW] 页面 \(remotePage.title) 发生冲突，自动收敛至最新版本")
                do {
                    try repository.save(mergedPage)
                    // pages[localIndex] = mergedPage // <- 移除：由 ValueObservation 自动同步
                    embeddingManager.updateEmbedding(for: mergedPage)
                } catch {
                    Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Sync remote failed: \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try repository.save(remotePage)
                // pages.append(remotePage) // <- 移除：由 ValueObservation 自动同步
                embeddingManager.updateEmbedding(for: remotePage)
            } catch {
                Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Insert remote failed: \(error.localizedDescription)")
            }
        }
    }

    /// 删除页面，并递归清理其他页面对该页面的 UUID 引用
    /// - Parameter page: 待删除的页面对象
    func deletePage(_ page: WikiPage) {
        // 首先移除其他页面中对该页面的引用
        for i in pages.indices {
            if pages[i].relatedPageIDs.contains(page.id) {
                var refPage = pages[i]
                refPage.relatedPageIDs.removeAll { $0 == page.id }
                try? repository.save(refPage)
            }
        }

        do {
            try repository.delete(id: page.id)
            onLog?(.delete, page.title, "")
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Delete page failed: \(error.localizedDescription)")
        }
    }

    /// 批量重命名全局标签
    /// - Parameters:
    ///   - oldTag: 旧标签名称
    ///   - newTag: 新标签名称
    func renameTag(_ oldTag: String, to newTag: String) {
        performBatchWrite { db in
            for p in self.pages {
                if let idx = p.tags.firstIndex(of: oldTag) {
                    var updated = p
                    updated.tags[idx] = newTag
                    try self.repository.save(updated)
                }
            }
        }
    }

    /// 批量从所有页面中移除指定标签
    /// - Parameter tag: 待移除的标签名称
    func deleteTag(_ tag: String) {
        performBatchWrite { db in
            for p in self.pages {
                if let idx = p.tags.firstIndex(of: tag) {
                    var updated = p
                    updated.tags.remove(at: idx)
                    try self.repository.save(updated)
                }
            }
        }
    }



    func clearAllData() {
        try? repository.deleteAll()
        // pages.removeAll() // <- 移除：由 ValueObservation 自动同步
        onSaveNeeded?()
    }

    // MARK: - 检索方法
    
    /// 根据 UUID 查找页面对象
    /// - Parameter id: 页面唯一标识
    /// - Returns: 找到的页面或 nil
    func pageByID(_ id: UUID) -> WikiPage? {
        pages.first { $0.id == id }
    }

    /// 根据标题或别名查找页面，支持大小写不敏感匹配
    /// - Parameter title: 目标标题或别名
    /// - Returns: 找到的页面或 nil
    func pageByTitle(_ title: String) -> WikiPage? {
        let lower = title.lowercased()
        if let exact = try? repository.fetchByTitle(title) {
            return exact
        }
        return pages.first { page in
            page.aliases.contains { $0.lowercased() == lower }
        }
    }

    /// 获取引用了指定页面的所有“反向链接”页面
    /// - Parameter pageID: 目标页面的 UUID
    /// - Returns: 引用者页面列表
    func fetchBacklinksByID(for pageID: UUID) -> [WikiPage] {
        guard let page = pageByID(pageID) else { return [] }
        let sourceIDs = (try? repository.fetchBacklinks(for: page.title)) ?? []
        return sourceIDs.compactMap { id in pageByID(id) }
    }

    /// 混合搜索，优先调用 FTS5 全文索引，若查询为空则返回全表
    /// - Parameter query: 搜索关键字
    /// - Returns: 匹配的页面列表
    func searchPages(query: String) -> [WikiPage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pages }
        
        do {
            return try repository.search(query: trimmed)
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Search failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 对 FTS5 关键字进行安全转义，防止 SQL 注入或语法错误
    /// - Parameter query: 原始查询字符串
    /// - Returns: 转义后的查询字符串
    private func sanitizeFTSQuery(_ query: String) -> String {
        // 在 FTS5 中，转义双引号的方式是使用两个双引号
        return query.replacingOccurrences(of: "\"", with: "\"\"")
    }

    /// 从查询字符串中提取关键词进行分词分析
    /// - Parameter query: 搜索字符串
    /// - Returns: 关键词数组
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

    // MARK: - 统计信息
    var totalPages: Int { (try? repository.count()) ?? 0 }
    var entityCount: Int { (try? repository.count(type: .entity)) ?? 0 }
    var conceptCount: Int { (try? repository.count(type: .concept)) ?? 0 }
    var sourceCount: Int { (try? repository.count(type: .source)) ?? 0 }
    var totalWords: Int { pages.reduce(0) { $0 + $1.wordCount } }

    // MARK: - 批量重构
    
    /// 全量替换现有数据，用于导入或同步
    /// - Parameter newPages: 新页面列表
    func replaceAllPages(_ newPages: [WikiPage]) {
        try? repository.deleteAll()
        for page in newPages {
            try? repository.save(page)
        }
    }

    /// 清空所有页面数据
    func removeAllPages() {
        try? repository.deleteAll()
    }

    // MARK: - 载入与重载
    
    /// 强制从磁盘重载数据，触发 UI 刷新
    func reloadFromDisk() {
        onSaveNeeded?()
    }

    /// 在首次启动时注入预置的欢迎页面与教学引导
    /// - Parameter logAction: 日志回调闭包
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
    
    /// 执行知识深度扫描，利用 TextChunkerProcessor 进行语义切分并异步向量化
    /// - Parameter page: 目标页面
    private func performDeepScan(for page: WikiPage) {
        let chunker = TextChunkerProcessor()
        let chunks = chunker.split(text: page.content)
        
        let manager = self.embeddingManager
        
        DispatchQueue.global(qos: .background).async {
            let texts = chunks.map { $0.text }
            _ = manager?.vectorizeChunks(chunks: texts) ?? []
            
            // 此处简化：未来可以在 Repository 中增加 saveChunks
            // try? self.repository.saveChunks(...) 
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
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?) {
        Logger.shared.addLog(action: action, target: target, details: details, duration: duration, startTime: startTime, endTime: endTime, module: module ?? "SQLiteStore")
    }
}


extension SQLiteStore: @unchecked Sendable {}


