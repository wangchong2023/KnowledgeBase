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
    var onLog: ((String, String, String) -> Void)?
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
        SecurityManager.shared.updateSignature(for: core.dbPath)
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
            
            SecurityManager.shared.updateSignature(for: core.dbPath)
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
        
        UserDefaults.standard.set(true, forKey: "has_seeded_initial_content")
        logAction(Localized.tr("logAction.systemInit"), "SystemVault", Localized.tr("log.seedSuccess"))
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
    static func generate(in store: SQLiteStore) {
        // 先清空现有数据，确保是“重建”行为
        store.removeAllPages()
        
        // 1. AI Agent 概述
        _ = store.createPage(
            title: "AI Agent：超越对话的大脑",
            type: .concept,
            content: """
            # 什么是 AI Agent？
            
            AI Agent (人工智能代理) 是指能够感知环境、进行推理并采取行动以实现目标的智能体。不同于传统的 [[大语言模型 (LLM)]] 仅能进行对话，Agent 具备了“行动力”。
            
            ## 核心公式
            **Agent = LLM + [[规划 (Planning)]] + [[记忆 (Memory)]] + [[工具使用 (Tool Use)]]**
            
            相关框架：AutoGPT, BabyAGI, LangChain
            """,
            tags: ["AI", "Agent", "架构"]
        )
        
        // 2. 规划
        _ = store.createPage(
            title: "规划 (Planning)",
            type: .concept,
            content: """
            # 规划 (Planning)
            
            规划是 Agent 解决复杂任务的基础。它通常分为以下几个子任务：
            
            1. **任务分解**: 将大目标拆解为可管理的小步骤 (如 Chain of Thought)。
            2. **自我反思**: 代理会对过去的行动进行修正和完善 (如 ReAct 模式)。
            
            这使得 [[AI Agent：超越对话的大脑]] 能够处理需要多步推理的问题。
            """,
            tags: ["AI", "Planning", "推理"]
        )
        
        // 3. 记忆
        _ = store.createPage(
            title: "记忆 (Memory)",
            type: .concept,
            content: """
            # 记忆 (Memory)
            
            记忆能力让 Agent 能够保持上下文连贯性：
            
            - **短期记忆**: 利用 [[大语言模型 (LLM)]] 的上下文窗口记录当前任务。
            - **长期记忆**: 利用外部存储 (如 [[向量数据库]]) 进行信息检索。
            
            [[AI Agent：超越对话的大脑]] 利用长期记忆来实现跨会话的知识沉淀。
            """,
            tags: ["AI", "Memory", "RAG"]
        )
        
        // 4. 工具使用
        _ = store.createPage(
            title: "工具使用 (Tool Use)",
            type: .concept,
            content: """
            # 工具使用 (Tool Use / Tool Calling)
            
            工具使用是 Agent 与现实世界交互的桥梁。Agent 可以通过 API 调用：
            
            - **实时搜索**: 获取最新资讯。
            - **代码执行**: 进行复杂的数学运算。
            - **文件操作**: 处理本地文档。
            
            这让 [[AI Agent：超越对话的大脑]] 真正具备了解决实际问题的能力。
            """,
            tags: ["AI", "ToolUse", "API"]
        )
        
        // 5. LLM 角色
        _ = store.createPage(
            title: "大语言模型 (LLM)",
            type: .concept,
            content: """
            # LLM 作为中枢神经
            
            在 [[AI Agent：超越对话的大脑]] 架构中，LLM 扮演了“大脑”的角色，负责理解、决策和任务分发。
            
            为了训练出更强的 Agent，通常需要使用 [[大语言模型训练流程]]，特别是针对函数调用 (Function Calling) 的专门微调。
            """,
            tags: ["AI", "LLM", "大脑"]
        )
    }
}
