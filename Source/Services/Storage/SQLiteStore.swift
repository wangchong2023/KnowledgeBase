import Foundation
import SQLite3
import NaturalLanguage

// MARK: - SQLite 存储门面 (组合了核心、迁移与种子数据)
/// 轻量级门面，组合了 SQLiteStoreCore, SQLiteMigrator 和 KMSeedData。
/// 所有的数据库操作都委派给 SQLiteStoreCore 执行。
final class SQLiteStore: ObservableObject {
    @Published var pages: [WikiPage] = []

    // MARK: - 子组件
    private let core: SQLiteStoreCore
    private let migrator: SQLiteMigrator
    private(set) var embeddingManager: EmbeddingManager!

    // MARK: - 回调钩子
    var onLog: ((String, String, String) -> Void)?
    var onSaveNeeded: (() -> Void)?

    // MARK: - 初始化
    init() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dbPath = docsDir.appendingPathComponent("km.sqlite3")

        self.core = SQLiteStoreCore(dbPath: dbPath)
        self.migrator = SQLiteMigrator(core: core, docsDir: docsDir)
        self.embeddingManager = EmbeddingManager(core: core)

        core.open()
        core.createTables()
        migrator.migrateIfNeeded()
        loadAllPages()
        
        // 启动后台向量同步
        embeddingManager.syncEmbeddings(pages: pages)
    }

    deinit {
        core.close()
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

        core.insertPage(page)
        pages.append(page)
        core.updateLinks(sourceID: page.id, targetTitles: page.outgoingLinks)
        embeddingManager.updateEmbedding(for: page)
        
        // 如果内容较长，或者强制开启深度扫描
        if forceDeepScan || content.count > 500 {
            performDeepScan(for: page)
        }

        onLog?(Localized.tr("logAction.create"), title, "\(Localized.tr("detail.pageType")): \(type.displayName)")
        return page
    }

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
            
            onLog?(Localized.tr("logAction.update"), page.title, "")
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

        onLog?(Localized.tr("logAction.delete"), page.title, "")
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
    }

    func reloadFromDisk() {
        loadAllPages()
        onSaveNeeded?()
    }

    // MARK: - 种子数据
    /// 在首次启动时创建欢迎页面。
    func seedDefaultContent(logAction: (String, String, String) -> Void) {
        // 1. 欢迎页
        _ = createPage(
            title: "👋 欢迎使用 智元",
            type: .concept,
            content: """
            # 欢迎来到您的第二大脑
            
            智元 是一个“AI 原生”的知识进化引擎。它不仅能帮您存储笔记，还能通过 [[3D 图谱]] 发现知识间的隐秘联系。
            
            ### 快速开始
            - 尝试点击右侧的 [[智能对话]] 按钮，问我：“我库里有哪些内容？”
            - 拖入一个 PDF 到“导入”页面，体验 AI 自动拆解。
            - 在任意页面输入 `[[` 尝试创建链接。
            """,
            tags: ["入门", "欢迎"]
        )
        
        // 2. 关于图谱
        _ = createPage(
            title: "3D 图谱",
            type: .concept,
            content: """
            # 3D 知识拓扑
            
            在 智元 中，知识是以节点形式存在的。
            当您在 [[👋 欢迎使用 智元]] 中提到本页面时，系统会自动建立一条连线。
            
            随着内容增多，您会看到知识的“聚类”现象。
            """,
            tags: ["可视化", "图谱"]
        )
        
        // 3. AI 助手指南
        _ = createPage(
            title: "智能对话",
            type: .concept,
            content: """
            # 您的 AI 知识管家
            
            底部的 Chat 视图集成了 RAG (检索增强生成) 技术。
            它会检索您的 [[3D 图谱]]，确保回答的内容完全基于您的个人知识库。
            """,
            tags: ["AI", "RAG"]
        )
        
        logAction("SEED", "WelcomeVault", "Success")
    }
    
    // MARK: - RAG & Deep Scan
    
    private func performDeepScan(for page: WikiPage) {
        let chunker = RecursiveChunker()
        let chunks = chunker.split(text: page.content)
        
        // 异步执行向量化与存储
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let texts = chunks.map { $0.text }
            let embeddings = self.embeddingManager.vectorizeChunks(chunks: texts)
            self.core.saveChunks(pageID: page.id, chunks: chunks, embeddings: embeddings)
        }
    }
}

// MARK: - AnyPageStore 协议实现
extension SQLiteStore: AnyPageStore {
    @discardableResult
    func createPage(title: String, type: PageType, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, forceDeepScan: Bool) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags, sourceURL: sourceURL, rawSnippet: rawSnippet, forceDeepScan: forceDeepScan)
    }
}
