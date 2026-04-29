import Foundation
import SQLite3

// MARK: - SQLite Store Core (Database Layer)
/// Core SQLite operations: database lifecycle, CRUD, indexing, and query helpers.
/// Separated from persistence layer concerns (migration, seeding) for clarity.
final class SQLiteStoreCore {
    private(set) var db: OpaquePointer?
    let dbPath: URL

    init(dbPath: URL) {
        self.dbPath = dbPath
    }

    // MARK: - Database Lifecycle
    func open() {
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            print("[SQLiteStore] Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        applyPerformancePragmas()
    }

    func close() {
        sqlite3_close(db)
        db = nil
    }

    private func applyPerformancePragmas() {
        executeSQL("PRAGMA journal_mode=WAL")
        executeSQL("PRAGMA synchronous=NORMAL")
        executeSQL("PRAGMA cache_size=-4096")
    }

    // MARK: - Schema
    func createTables() {
        let createPagesTable = """
        CREATE TABLE IF NOT EXISTS pages (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'concept',
            custom_icon TEXT,
            content TEXT DEFAULT '',
            aliases TEXT DEFAULT '[]',
            tags TEXT DEFAULT '[]',
            status TEXT NOT NULL DEFAULT 'active',
            confidence TEXT NOT NULL DEFAULT 'medium',
            sources TEXT DEFAULT '[]',
            related_page_ids TEXT DEFAULT '[]',
            is_pinned INTEGER NOT NULL DEFAULT 0,
            created REAL NOT NULL,
            updated REAL NOT NULL
        );
        """
        executeSQL(createPagesTable)

        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_pages_title ON pages(title);",
            "CREATE INDEX IF NOT EXISTS idx_pages_type ON pages(type);",
            "CREATE INDEX IF NOT EXISTS idx_pages_status ON pages(status);",
            "CREATE INDEX IF NOT EXISTS idx_pages_updated ON pages(updated DESC);",
            "CREATE INDEX IF NOT EXISTS idx_pages_is_pinned ON pages(is_pinned);",
            "CREATE INDEX IF NOT EXISTS idx_pages_tags ON pages(tags);",
        ]
        indexes.forEach { executeSQL($0) }
    }

    // MARK: - CRUD (Raw SQL)
    func insertPage(_ page: WikiPage) {
        let sql = """
        INSERT OR REPLACE INTO pages (
            id, title, type, custom_icon, content, aliases, tags,
            status, confidence, sources, related_page_ids, is_pinned, created, updated
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let jsonData = try! JSONEncoder().encode([
            page.aliases, page.tags, page.sources, page.relatedPageIDs.map(\.uuidString)
        ])
        let arrays = try! JSONDecoder().decode([[String]].self, from: jsonData)

        sqlite3_bind_text(stmt, 1, page.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, page.title, -1, transient())
        sqlite3_bind_text(stmt, 3, page.type.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 4, page.customIcon ?? "", -1, transient())
        sqlite3_bind_text(stmt, 5, page.content, -1, transient())
        bindJSONString(stmt, 6, arrays[0])
        bindJSONString(stmt, 7, arrays[1])
        sqlite3_bind_text(stmt, 8, page.status.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 9, page.confidence.rawValue, -1, staticDestructor())
        bindJSONString(stmt, 10, arrays[2])
        bindJSONString(stmt, 11, arrays[3])
        sqlite3_bind_int(stmt, 12, page.isPinned ? 1 : 0)
        sqlite3_bind_double(stmt, 13, page.created.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 14, page.updated.timeIntervalSince1970)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("[SQLiteStore] Insert failed: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    func updatePage(_ page: WikiPage) {
        let sql = """
        UPDATE pages SET
            title=?, type=?, custom_icon=?, content=?, aliases=?,
            tags=?, status=?, confidence=?, sources=?, related_page_ids=?,
            is_pinned=?, updated=?
        WHERE id=?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let jsonData = try! JSONEncoder().encode([
            page.aliases, page.tags, page.sources, page.relatedPageIDs.map(\.uuidString)
        ])
        let arrays = try! JSONDecoder().decode([[String]].self, from: jsonData)

        sqlite3_bind_text(stmt, 1, page.title, -1, transient())
        sqlite3_bind_text(stmt, 2, page.type.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 3, page.customIcon ?? "", -1, transient())
        sqlite3_bind_text(stmt, 4, page.content, -1, transient())
        bindJSONString(stmt, 5, arrays[0])
        bindJSONString(stmt, 6, arrays[1])
        sqlite3_bind_text(stmt, 7, page.status.rawValue, -1, staticDestructor())
        sqlite3_bind_text(stmt, 8, page.confidence.rawValue, -1, staticDestructor())
        bindJSONString(stmt, 9, arrays[2])
        bindJSONString(stmt, 10, arrays[3])
        sqlite3_bind_int(stmt, 11, page.isPinned ? 1 : 0)
        sqlite3_bind_double(stmt, 12, page.updated.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 13, page.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        sqlite3_step(stmt)
    }

    func deletePage(id: UUID) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM pages WHERE id = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
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

    func countPages() -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM pages;", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Row Decoding
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
        let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
        let updated = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 13))

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
            created: created,
            updated: updated
        )
    }

    // MARK: - SQL Helpers
    func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK else { return }
        if let msg = errMsg {
            print("[SQLiteStore] SQL error: \(String(cString: msg))")
            sqlite3_free(errMsg)
        }
    }

    func beginTransaction() {
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
    }

    func commitTransaction() {
        sqlite3_exec(db, "COMMIT TRANSACTION", nil, nil, nil)
    }

    // MARK: - Binding Helpers
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
            sqlite3_bind_text(stmt, index, cstr, Int32(str.utf8.count), transient())
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
}
