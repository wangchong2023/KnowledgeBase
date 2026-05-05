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
    private var observationTask: Task<Void, Never>?
    private var currentTransaction: DatabaseWriter? // 临时持有用于事务

    // MARK: - 回调钩子
    var onLog: ((LogAction, String, String) -> Void)?
    var onSaveNeeded: (() -> Void)?
    
    var dbPath: URL { 
        // 核心修复：通过 dbWriter 协议安全获取路径，避免在 DatabaseQueue 模式下强行解包 dbPool
        URL(fileURLWithPath: DatabaseManager.shared.dbWriter?.path ?? "") 
    }

    // MARK: - 初始化
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

    /// 使用泛型方法启动观察，以“打开” existential type (any DatabaseReader)
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

    func close() {
        observationTask?.cancel()
    }

    deinit {
        // Resources are managed by DatabasePool automatically.
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

    /// 执行批量写入事务（推荐方式）
    func performBatchWrite(_ updates: @escaping (Database) throws -> Void) {
        do {
            try DatabaseManager.shared.dbWriter?.write(updates)
        } catch {
            Logger.shared.addLog(action: .error, target: "SQLiteStore", details: "Batch write failed: \(error.localizedDescription)")
        }
    }

    /// 更新现有页面
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

    /// 同步远程页面 (核心 LWW 冲突解决逻辑)
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

    /// 删除页面，并处理相关的引用清理
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

    /// 批量重命名标签
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

    /// 批量删除标签
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
    
    func pageByID(_ id: UUID) -> WikiPage? {
        pages.first { $0.id == id }
    }

    func pageByTitle(_ title: String) -> WikiPage? {
        let lower = title.lowercased()
        if let exact = try? repository.fetchByTitle(title) {
            return exact
        }
        return pages.first { page in
            page.aliases.contains { $0.lowercased() == lower }
        }
    }

    /// 获取引用了指定页面的所有页面
    func fetchBacklinksByID(for pageID: UUID) -> [WikiPage] {
        guard let page = pageByID(pageID) else { return [] }
        let sourceIDs = (try? repository.fetchBacklinks(for: page.title)) ?? []
        return sourceIDs.compactMap { id in pageByID(id) }
    }

    /// 混合搜索
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

    // MARK: - 统计信息
    var totalPages: Int { (try? repository.count()) ?? 0 }
    var entityCount: Int { (try? repository.count(type: .entity)) ?? 0 }
    var conceptCount: Int { (try? repository.count(type: .concept)) ?? 0 }
    var sourceCount: Int { (try? repository.count(type: .source)) ?? 0 }
    var totalWords: Int { pages.reduce(0) { $0 + $1.wordCount } }

    // MARK: - 批量操作
    func replaceAllPages(_ newPages: [WikiPage]) {
        try? repository.deleteAll()
        for page in newPages {
            try? repository.save(page)
        }
        // pages = newPages // <- 移除：由 ValueObservation 自动同步
    }

    func removeAllPages() {
        try? repository.deleteAll()
        // pages = [] // <- 移除：由 ValueObservation 自动同步
    }

    // MARK: - 载入与重载
    func reloadFromDisk() {
        // 由于有 ValueObservation，通常不需要手动重载，
        // 但如果需要强制刷新 UI 状态，可以调用此方法。
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
}


extension SQLiteStore: @unchecked Sendable {}


