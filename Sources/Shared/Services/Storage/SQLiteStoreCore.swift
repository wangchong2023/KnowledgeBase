import Foundation
import SQLite3

// MARK: - SQLite 存储核心 (数据库层)
/// 核心 SQLite 操作：处理数据库生命周期、CRUD、索引和查询辅助方法。
/// 与持久化层关注点（迁移、植入数据）分离，确保职责清晰。
final class SQLiteStoreCore {
    private(set) var db: OpaquePointer?
    let dbPath: URL

    // MARK: - 字段定义 (集中管理，避免硬编码)
    enum Columns {
        static let id = "id"
        static let title = "title"
        static let type = "type"
        static let icon = "custom_icon"
        static let content = "content"
        static let aliases = "aliases"
        static let tags = "tags"
        static let status = "status"
        static let confidence = "confidence"
        static let sources = "sources"
        static let relatedIDs = "related_page_ids"
        static let isPinned = "is_pinned"
        static let hash = "content_hash"
        static let sourceURL = "source_url"
        static let rawSnippet = "raw_snippet"
        static let created = "created"
        static let updated = "updated"
        
        // Embeddings Table
        static let embeddingTable = "page_embeddings"
        static let embeddingBlob = "vector_blob"
        static let embeddingModel = "model_name"
        
        // Links Table
        static let linksTable = "links"
        static let sourceID = "source_id"
        static let targetTitle = "target_title"
        static let context = "context"
    }

    init(dbPath: URL) {
        self.dbPath = dbPath
    }

    // MARK: - 数据库生命周期
    func open() {
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            LogService.shared.error("[SQLiteStore] 无法打开数据库", error: nil)
            return
        }
        applyPerformancePragmas()
    }

    func close() {
        sqlite3_close(db)
        db = nil
    }

    /// 应用性能优化参数
    private func applyPerformancePragmas() {
        executeSQL("PRAGMA journal_mode=WAL") // 启用预写日志模式，提高并发性能
        executeSQL("PRAGMA synchronous=NORMAL") // 兼顾安全与速度的同步模式
        executeSQL("PRAGMA cache_size=-4096") // 设置缓存大小为 4MB
    }

    // MARK: - 架构
    func createTables() {
        // 1. 定义完整 Schema 描述
        let schema = [
            "\(Columns.id) TEXT PRIMARY KEY",
            "\(Columns.title) TEXT NOT NULL",
            "\(Columns.type) TEXT NOT NULL DEFAULT 'concept'",
            "\(Columns.icon) TEXT",
            "\(Columns.content) TEXT DEFAULT ''",
            "\(Columns.aliases) TEXT DEFAULT '[]'",
            "\(Columns.tags) TEXT DEFAULT '[]'",
            "\(Columns.status) TEXT NOT NULL DEFAULT 'active'",
            "\(Columns.confidence) TEXT NOT NULL DEFAULT 'medium'",
            "\(Columns.sources) TEXT DEFAULT '[]'",
            "\(Columns.relatedIDs) TEXT DEFAULT '[]'",
            "\(Columns.isPinned) INTEGER NOT NULL DEFAULT 0",
            "\(Columns.hash) TEXT",
            "\(Columns.sourceURL) TEXT",
            "\(Columns.rawSnippet) TEXT",
            "\(Columns.created) REAL NOT NULL",
            "\(Columns.updated) REAL NOT NULL"
        ]
        
        let createPagesTable = "CREATE TABLE IF NOT EXISTS pages (\(schema.joined(separator: ", ")));"
        executeSQL(createPagesTable)

        // 2. 定义需要索引的字段列表，自动生成索引语句
        let indexedColumns = [Columns.title, Columns.type, Columns.status, Columns.updated, Columns.isPinned, Columns.tags]
        indexedColumns.forEach { col in
            executeSQL("CREATE INDEX IF NOT EXISTS idx_pages_\(col) ON pages(\(col)\(col == Columns.updated ? " DESC" : ""));")
        }

        // --- 全文搜索增强 (FTS5) ---
        createFTSTables()
        
        // --- 向量存储表 ---
        let createEmbeddingsTable = """
        CREATE TABLE IF NOT EXISTS \(Columns.embeddingTable) (
            \(Columns.id) TEXT PRIMARY KEY,
            \(Columns.embeddingBlob) BLOB NOT NULL,
            \(Columns.embeddingModel) TEXT NOT NULL,
            \(Columns.updated) REAL NOT NULL,
            FOREIGN KEY (\(Columns.id)) REFERENCES pages (\(Columns.id)) ON DELETE CASCADE
        );
        """
        executeSQL(createEmbeddingsTable)

        // 4. Page Chunks Table (For Long Document RAG)
        let createChunksTable = """
        CREATE TABLE IF NOT EXISTS page_chunks (
            id TEXT PRIMARY KEY,
            page_id TEXT NOT NULL,
            content TEXT NOT NULL,
            embedding BLOB,
            start_index INTEGER,
            FOREIGN KEY(page_id) REFERENCES pages(id) ON DELETE CASCADE
        );
        """
        executeSQL(createChunksTable)
        executeSQL("CREATE INDEX IF NOT EXISTS idx_chunks_page_id ON page_chunks(page_id)")

        // 5. Links Table (For O(1) Backlinks Lookup)
        let createLinksTable = """
        CREATE TABLE IF NOT EXISTS \(Columns.linksTable) (
            \(Columns.sourceID) TEXT NOT NULL,
            \(Columns.targetTitle) TEXT NOT NULL,
            \(Columns.context) TEXT,
            PRIMARY KEY (\(Columns.sourceID), \(Columns.targetTitle)),
            FOREIGN KEY (\(Columns.sourceID)) REFERENCES pages (\(Columns.id)) ON DELETE CASCADE
        );
        """
        executeSQL(createLinksTable)
        executeSQL("CREATE INDEX IF NOT EXISTS idx_links_target ON \(Columns.linksTable)(\(Columns.targetTitle))")
    }

    /// 优雅地创建 FTS5 虚拟表及同步触发器
    private func createFTSTables() {
        // 1. 定义需要索引的字段列表（未来增加搜索字段只需在此修改）
        let ftsColumns = [Columns.title, Columns.content, Columns.tags, Columns.aliases]
        let colList = ftsColumns.joined(separator: ", ")
        let oldColList = ftsColumns.map { "old.\($0)" }.joined(separator: ", ")
        let newColList = ftsColumns.map { "new.\($0)" }.joined(separator: ", ")

        // 2. 创建虚拟表
        let createFTS = "CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(\(colList), content='pages', content_rowid='rowid');"
        executeSQL(createFTS)

        // 3. 定义触发器模板（通过动态字段列表填充）
        let triggers = [
            "CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON pages BEGIN INSERT INTO pages_fts(rowid, \(colList)) VALUES (new.rowid, \(newColList)); END;",
            "CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON pages BEGIN INSERT INTO pages_fts(pages_fts, rowid, \(colList)) VALUES('delete', old.rowid, \(oldColList)); END;",
            "CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON pages BEGIN INSERT INTO pages_fts(pages_fts, rowid, \(colList)) VALUES('delete', old.rowid, \(oldColList)); INSERT INTO pages_fts(rowid, \(colList)) VALUES (new.rowid, \(newColList)); END;"
        ]
        
        triggers.forEach { executeSQL($0) }
    }

    // MARK: - CRUD 操作 (原始 SQL)
    
    /// 获取 WikiPage 的四个数组字段作为原始 [String] 数组元组。
    /// JSON 编码由 bindJSONString 处理以避免重复。
    private func pageArrayFields(_ page: WikiPage) -> ([String], [String], [String], [String]) {
        (page.aliases, page.tags, page.sources, page.relatedPageIDs.map(\.uuidString))
    }
    
    func insertPage(_ page: WikiPage) {
        let sql = """
        INSERT OR REPLACE INTO pages (
            \(Columns.id), \(Columns.title), \(Columns.type), \(Columns.icon), \(Columns.content), \(Columns.aliases), \(Columns.tags),
            \(Columns.status), \(Columns.confidence), \(Columns.sources), \(Columns.relatedIDs), \(Columns.isPinned), \(Columns.hash),
            \(Columns.sourceURL), \(Columns.rawSnippet), \(Columns.created), \(Columns.updated)
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let arrays = pageArrayFields(page)

        sqlite3_bind_text(stmt, 1, page.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, page.title, -1, transient())
        sqlite3_bind_text(stmt, 3, page.type.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 4, page.customIcon ?? "", -1, transient())
        sqlite3_bind_text(stmt, 5, page.content, -1, transient())
        bindJSONString(stmt, 6, arrays.0)
        bindJSONString(stmt, 7, arrays.1)
        sqlite3_bind_text(stmt, 8, page.status.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 9, page.confidence.rawValue, -1, staticDestructor())
        bindJSONString(stmt, 10, arrays.2)
        bindJSONString(stmt, 11, arrays.3)
        sqlite3_bind_int(stmt, 12, page.isPinned ? 1 : 0)
        if let hash = page.contentHash {
            sqlite3_bind_text(stmt, 13, hash, -1, transient())
        } else {
            sqlite3_bind_null(stmt, 13)
        }
        sqlite3_bind_text(stmt, 14, page.sourceURL ?? "", -1, transient())
        sqlite3_bind_text(stmt, 15, page.rawTextSnippet ?? "", -1, transient())
        sqlite3_bind_double(stmt, 16, page.created.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 17, page.updated.timeIntervalSince1970)

        if sqlite3_step(stmt) != SQLITE_DONE {
            LogService.shared.error("[SQLiteStore] 插入失败", error: nil)
        }
    }

    func updatePage(_ page: WikiPage) {
        let sql = """
        UPDATE pages SET
            \(Columns.title)=?, \(Columns.type)=?, \(Columns.icon)=?, \(Columns.content)=?, \(Columns.aliases)=?,
            \(Columns.tags)=?, \(Columns.status)=?, \(Columns.confidence)=?, \(Columns.sources)=?, \(Columns.relatedIDs)=?,
            \(Columns.isPinned)=?, \(Columns.hash)=?, \(Columns.sourceURL)=?, \(Columns.rawSnippet)=?, \(Columns.updated)=?
        WHERE \(Columns.id)=?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let arrays = pageArrayFields(page)

        sqlite3_bind_text(stmt, 1, page.title, -1, transient())
        sqlite3_bind_text(stmt, 2, page.type.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 3, page.customIcon ?? "", -1, transient())
        sqlite3_bind_text(stmt, 4, page.content, -1, transient())
        bindJSONString(stmt, 5, arrays.0)
        bindJSONString(stmt, 6, arrays.1)
        sqlite3_bind_text(stmt, 7, page.status.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 8, page.confidence.rawValue, -1, staticDestructor())
        bindJSONString(stmt, 9, arrays.2)
        bindJSONString(stmt, 10, arrays.3)
        sqlite3_bind_int(stmt, 11, page.isPinned ? 1 : 0)
        if let hash = page.contentHash {
            sqlite3_bind_text(stmt, 12, hash, -1, transient())
        } else {
            sqlite3_bind_null(stmt, 12)
        }
        sqlite3_bind_text(stmt, 13, page.sourceURL ?? "", -1, transient())
        sqlite3_bind_text(stmt, 14, page.rawTextSnippet ?? "", -1, transient())
        sqlite3_bind_double(stmt, 15, page.updated.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 16, page.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        sqlite3_step(stmt)
    }

    // MARK: - Link Index Operations
    
    func updateLinks(sourceID: UUID, targetTitles: [String]) {
        // 1. 清理旧链接
        executeSQL("DELETE FROM \(Columns.linksTable) WHERE \(Columns.sourceID) = '\(sourceID.uuidString)';")
        
        guard !targetTitles.isEmpty else { return }
        
        // 2. 批量插入新链接 (使用事务保证原子性)
        let sql = "INSERT OR IGNORE INTO \(Columns.linksTable) (\(Columns.sourceID), \(Columns.targetTitle)) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        
        for title in targetTitles {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, sourceID.uuidString, -1, transient())
            sqlite3_bind_text(stmt, 2, title, -1, transient())
            sqlite3_step(stmt)
        }
    }
    
    func fetchBacklinks(for targetTitle: String) -> [UUID] {
        let sql = "SELECT \(Columns.sourceID) FROM \(Columns.linksTable) WHERE \(Columns.targetTitle) = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, targetTitle, -1, transient())
        
        var result: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let idStr = sqlite3_column_text(stmt, 0),
               let uuid = UUID(uuidString: String(cString: idStr)) {
                result.append(uuid)
            }
        }
        return result
    }

    func deletePage(id: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM pages WHERE \(Columns.id) = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
        
        // 同时清理向量数据
        executeSQL("DELETE FROM \(Columns.embeddingTable) WHERE \(Columns.id) = '\(id.uuidString)';")
    }

    // MARK: - Embedding Operations
    
    func saveEmbedding(id: UUID, embedding: [Float], model: String) {
        let sql = "INSERT OR REPLACE INTO \(Columns.embeddingTable) (\(Columns.id), \(Columns.embeddingBlob), \(Columns.embeddingModel), \(Columns.updated)) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        
        let data = Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size)
        
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, transient())
        sqlite3_bind_blob(stmt, 2, (data as NSData).bytes, Int32(data.count), transient())
        sqlite3_bind_text(stmt, 3, model, -1, transient())
        sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
        
        if sqlite3_step(stmt) != SQLITE_DONE {
            LogService.shared.error("[SQLiteStore] Embedding 保存失败", error: nil)
        }
    }
    
    func getEmbedding(id: UUID) -> [Float]? {
        let sql = "SELECT \(Columns.embeddingBlob) FROM \(Columns.embeddingTable) WHERE \(Columns.id) = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, transient())
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let blob = sqlite3_column_blob(stmt, 0) {
                let count = Int(sqlite3_column_bytes(stmt, 0)) / MemoryLayout<Float>.size
                let pointer = blob.assumingMemoryBound(to: Float.self)
                return Array(UnsafeBufferPointer(start: pointer, count: count))
            }
        }
        return nil
    }
    
    func selectAllEmbeddings() -> [UUID: [Float]] {
        let sql = "SELECT \(Columns.id), \(Columns.embeddingBlob) FROM \(Columns.embeddingTable);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        
        var result: [UUID: [Float]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            if let uuid = UUID(uuidString: idStr),
               let blob = sqlite3_column_blob(stmt, 1) {
                let count = Int(sqlite3_column_bytes(stmt, 1)) / MemoryLayout<Float>.size
                let pointer = blob.assumingMemoryBound(to: Float.self)
                let vector = Array(UnsafeBufferPointer(start: pointer, count: count))
                result[uuid] = vector
            }
        }
        return result
    }

    func deleteAllPages() {
        executeSQL("DELETE FROM pages;")
    }

    func selectAllPages() -> [WikiPage] {
        let sql = "SELECT * FROM pages ORDER BY is_pinned DESC, updated DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var result: [WikiPage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let page = decodePage(stmt) {
                result.append(page)
            }
        }
        return result
    }

    func selectPageByColumn(_ column: String, value: String) -> WikiPage? {
        let sql = "SELECT * FROM pages WHERE \(column) = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, value, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return decodePage(stmt)
    }

    /// 执行高性能 FTS5 全文搜索
    func searchPagesFTS(query: String) -> [WikiPage] {
        // 使用 MATCH 操作符进行模糊匹配，按相关度排序
        let sql = """
        SELECT pages.* FROM pages 
        JOIN pages_fts ON pages.rowid = pages_fts.rowid 
        WHERE pages_fts MATCH ? 
        ORDER BY rank;
        """
        
        var stmt: OpaquePointer?
        // SQLite FTS5 的模糊查询通常需要 query + "*" 来匹配前缀
        let searchQuery = query.contains("*") ? query : "\(query)*"
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, searchQuery, -1, transient())
        
        var result: [WikiPage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let page = decodePage(stmt) {
                result.append(page)
            }
        }
        return result
    }

    // MARK: - 高效统计方法
    
    /// 获取页面总数
    func countPages() -> Int {
        countByQuery("SELECT COUNT(*) FROM pages;")
    }
    
    /// 按类型获取页面数量
    func countPages(type: String) -> Int {
        countByQuery("SELECT COUNT(*) FROM pages WHERE type = '\(type)';")
    }
    
    /// 获取待完善（Stub）页面数量
    func countStubPages() -> Int {
        countByQuery("SELECT COUNT(*) FROM pages WHERE status = 'stub';")
    }
    
    /// 获取活跃（Active）页面数量
    func countActivePages() -> Int {
        countByQuery("SELECT COUNT(*) FROM pages WHERE status = 'active';")
    }
    
    private func countByQuery(_ sql: String) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - 行解码
    private func decodePage(_ stmt: OpaquePointer?) -> WikiPage? {
        guard let stmt = stmt else { return nil }

        let idString = String(cString: sqlite3_column_text(stmt, 0))
        let title = columnText(stmt, 1)
        let typeRaw = columnText(stmt, 2)
        let customIcon = columnOptionalText(stmt, 3)
        let content = columnText(stmt, 4)
        let aliases = columnJSONArray(stmt, 5)
        let tags = columnJSONArray(stmt, 6)
        let statusRaw = columnText(stmt, 7)
        let confidenceRaw = columnText(stmt, 8)
        let sources = columnJSONArray(stmt, 9)
        let relatedIDStrings = columnJSONArray(stmt, 10)
        let isPinned = sqlite3_column_int(stmt, 11) != 0
        let contentHash = columnOptionalText(stmt, 12)
        let sourceURL = columnOptionalText(stmt, 13)
        let rawSnippet = columnOptionalText(stmt, 14)
        let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 15))
        let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 16))

        guard let uuid = UUID(uuidString: idString),
              let type = PageType(rawValue: typeRaw),
              let status = PageStatus(rawValue: statusRaw),
              let confidence = Confidence(rawValue: confidenceRaw) else {
            return nil
        }

        return WikiPage(
            id: uuid,
            title: title,
            type: type,
            customIcon: customIcon.isEmpty ? nil : customIcon,
            content: content,
            aliases: aliases,
            tags: tags,
            status: status,
            confidence: confidence,
            sources: sources,
            relatedPageIDs: relatedIDStrings.compactMap { UUID(uuidString: $0) },
            isPinned: isPinned,
            contentHash: contentHash.isEmpty ? nil : contentHash,
            sourceURL: sourceURL.isEmpty ? nil : sourceURL,
            rawTextSnippet: rawSnippet.isEmpty ? nil : rawSnippet,
            created: created,
            updated: updated
        )
    }

    // MARK: - SQL 辅助方法
    func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK else { return }
        if let msg = errMsg {
            print("[SQLiteStore] SQL 错误: \(String(cString: msg))")
            sqlite3_free(errMsg)
        }
    }

    func beginTransaction() {
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
    }

    func commitTransaction() {
        sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil)
    }

    // MARK: - 绑定辅助方法
    private func transient() -> sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private func staticDestructor() -> sqlite3_destructor_type {
        unsafeBitCast(0, to: sqlite3_destructor_type.self)
    }

    private func bindJSONString(_ stmt: OpaquePointer?, _ index: Int32, _ array: [String]) {
        guard let data = try? JSONEncoder().encode(array),
              let str = String(data: data, encoding: .utf8) else {
            sqlite3_bind_null(stmt, index)
            return
        }
        str.withCString { cstr in
            _ = sqlite3_bind_text(stmt, index, cstr, Int32(str.utf8.count), transient())
        }
    }

    private func columnText(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        guard let text = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: text)
    }

    private func columnOptionalText(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
              let text = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: text)
    }

    private func columnJSONArray(_ stmt: OpaquePointer?, _ col: Int32) -> [String] {
        let raw = columnText(stmt, col)
        guard let data = raw.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    // MARK: - Chunks & RAG Support
    
    func saveChunks(pageID: UUID, chunks: [RecursiveChunker.Chunk], embeddings: [[Float]]) {
        guard let db = db else { return }
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil) }

        // 清理旧分块
        var deleteStmt: OpaquePointer?
        let deleteSQL = "DELETE FROM page_chunks WHERE page_id = ?"
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(deleteStmt, 1, pageID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(deleteStmt)
        sqlite3_finalize(deleteStmt)

        // 插入新分块
        let insertSQL = "INSERT INTO page_chunks (id, page_id, content, embedding, start_index) VALUES (?, ?, ?, ?, ?)"
        var insertStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else { return }
        for (i, chunk) in chunks.enumerated() {
            sqlite3_reset(insertStmt)
            sqlite3_clear_bindings(insertStmt)
            let vectorData = Data(bytes: embeddings[i], count: embeddings[i].count * MemoryLayout<Float>.size)
            sqlite3_bind_text(insertStmt, 1, UUID().uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertStmt, 2, pageID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insertStmt, 3, chunk.text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            let _ = vectorData.withUnsafeBytes { ptr in
                sqlite3_bind_blob(insertStmt, 4, ptr.baseAddress, Int32(vectorData.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            sqlite3_bind_int(insertStmt, 5, Int32(chunk.startIndex))
            sqlite3_step(insertStmt)
        }
        sqlite3_finalize(insertStmt)
    }

    func fetchChunks(pageID: UUID) -> [(content: String, embedding: [Float])] {
        guard let db = db else { return [] }
        var results: [(content: String, embedding: [Float])] = []
        let sql = "SELECT content, embedding FROM page_chunks WHERE page_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        sqlite3_bind_text(stmt, 1, pageID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let content = String(cString: sqlite3_column_text(stmt, 0))
            var vector: [Float] = []
            if let blob = sqlite3_column_blob(stmt, 1) {
                let count = Int(sqlite3_column_bytes(stmt, 1)) / MemoryLayout<Float>.size
                let ptr = blob.assumingMemoryBound(to: Float.self)
                vector = Array(UnsafeBufferPointer(start: ptr, count: count))
            }
            results.append((content, vector))
        }
        sqlite3_finalize(stmt)
        return results
    }
}

