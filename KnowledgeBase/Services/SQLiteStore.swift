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
        embeddingManager.updateEmbedding(for: page)
        
        // 如果内容较长，或者强制开启深度扫描
        if forceDeepScan || content.count > 500 {
            performDeepScan(for: page)
        }

        onLog?(Localized.tr("logAction.create"), title, "\(Localized.tr("detail.pageType")): \(type.displayName)")
        return page
    }

    /// 更新现有页面
    func updatePage(_ page: WikiPage, forceDeepScan: Bool = false) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            var updated = page
            updated.updated = Date()
            pages[index] = updated
            core.updatePage(updated)
            embeddingManager.updateEmbedding(for: updated)
            
            // 重新评估并更新深度扫描分块
            if forceDeepScan || updated.content.count > 500 {
                performDeepScan(for: updated)
            }
            
            onLog?(Localized.tr("logAction.update"), page.title, "")
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

    /// 混合搜索（对标 Karpathy 模式：关键词 + 语义提取）
    func searchPages(query: String) -> [WikiPage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pages }

        // 1. 语义预处理：提取名词和核心词
        let keywords = extractSearchKeywords(from: trimmed)
        
        // 2. 构建混合 FTS5 查询 (原词权重最高，关键词次之)
        // 示例: "Karpathy" -> "Karpathy* OR (Andrej* AND Wiki*)"
        var finalQuery = "\"\(trimmed)\"*^5" // 精确短语优先
        if !keywords.isEmpty {
            let semanticPart = keywords.map { "\($0)*" }.joined(separator: " OR ")
            finalQuery += " OR (\(semanticPart))"
        }

        // 直接调用底层 FTS5 引擎进行检索
        return core.searchPagesFTS(query: finalQuery)
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
        _ = createPage(
            title: Localized.tr("page.firstPageTitle"),
            type: .concept,
            content: """
            # \(Localized.tr("page.firstPageTitle"))

            \(Localized.tr("page.firstPageContent"))
            """,
            tags: []
        )
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
    func createPage(title: String, type: PageType, content: String = "", tags: [String] = [], sourceURL: String? = nil, rawSnippet: String? = nil, forceDeepScan: Bool = false) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags, sourceURL: sourceURL, rawSnippet: rawSnippet, forceDeepScan: forceDeepScan)
    }
    
    func updatePage(_ page: WikiPage, forceDeepScan: Bool = false) {
        updatePage(page, forceDeepScan: forceDeepScan)
    }
}
