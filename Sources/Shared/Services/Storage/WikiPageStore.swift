// WikiPageStore.swift
//
// 作者: Wang Chong
// 功能说明: 页面链接模型（用于反向链接 O(1) 查询）
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import GRDB

// MARK: - 数据库 Record 模型

/// 页面链接模型 (用于反向链接 O(1) 查询)
struct PageLink: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "links"

    var sourceID: UUID
    var targetTitle: String
    var context: String?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case targetTitle = "target_title"
        case context
    }
}

/// 页面嵌入向量模型
struct PageEmbedding: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "page_embeddings"

    var id: UUID
    var vectorBlob: Data
    var modelName: String
    var updated: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vectorBlob = "vector_blob"
        case modelName = "model_name"
        case updated
    }

    var vector: [Float] {
        let count = vectorBlob.count / MemoryLayout<Float>.size
        return vectorBlob.withUnsafeBytes { pointer in
            Array(UnsafeBufferPointer(start: pointer.baseAddress?.assumingMemoryBound(to: Float.self), count: count))
        }
    }

    init(id: UUID, vector: [Float], modelName: String, updated: Date = Date()) {
        self.id = id
        self.vectorBlob = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
        self.modelName = modelName
        self.updated = updated
    }
}

/// 页面分块模型 (用于 RAG)
struct PageChunk: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "page_chunks"

    var id: String
    var pageID: UUID
    var content: String
    var embedding: Data?
    var startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case pageID = "page_id"
        case content
        case embedding
        case startIndex = "start_index"
    }
}

/// 页面全文搜索映射模型
struct WikiPageFTS: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pages_fts"
    var title: String
    var content: String
    var tags: String
    var aliases: String
}

// MARK: - 核心存储 (WikiPageStore)

/// Wiki 页面存储：封装所有基于 GRDB 的高性能 CRUD 操作。
final class WikiPageStore {
    private let dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    // MARK: - 页面操作

    func save(_ page: WikiPage) throws {
        try dbWriter.write { db in
            try page.save(db)
        }
    }

    /// 在已有数据库事务中保存页面（避免重入写锁）
    func save(_ page: WikiPage, using db: Database) throws {
        try page.save(db)
    }

    func delete(id: UUID) throws {
        _ = try dbWriter.write { db in
            try WikiPage.deleteOne(db, id: id)
        }
    }

    func fetchAll() throws -> [WikiPage] {
        try dbWriter.read { db in
            try WikiPage.order(Column("updated").desc).fetchAll(db)
        }
    }

    func fetchByID(_ id: UUID) throws -> WikiPage? {
        try dbWriter.read { db in
            try WikiPage.fetchOne(db, id: id)
        }
    }

    func fetchByTitle(_ title: String) throws -> WikiPage? {
        try dbWriter.read { db in
            try WikiPage.filter(Column("title") == title).fetchOne(db)
        }
    }

    // MARK: - 全文搜索 (FTS5)

    func search(query: String) throws -> [WikiPage] {
        try dbWriter.read { db in
            guard let pattern = FTS5Pattern(matchingAllPrefixesIn: query) else { return [] }

            // 说明：由于 FTS5 的 MATCH 和 rank 排序在处理跨表 Association 时
            // 容易引发 Swift 编译器复杂的类型推断错误，此处采用 GRDB 推荐的 SQL 映射模式。
            // 这种方式在处理 FTS5 虚拟表关联时性能最优且逻辑最直观。
            let sql = """
                SELECT pages.* FROM pages
                JOIN pages_fts ON pages.rowid = pages_fts.rowid
                WHERE pages_fts MATCH ?
                ORDER BY rank
            """
            return try WikiPage.fetchAll(db, sql: sql, arguments: [pattern])
        }
    }

    // MARK: - 反向链接 (Links)

    func saveLinks(sourceID: UUID, targetTitles: [String]) throws {
        try dbWriter.write { db in
            try PageLink.filter(Column("source_id") == sourceID).deleteAll(db)
            for title in targetTitles {
                let link = PageLink(sourceID: sourceID, targetTitle: title)
                try link.insert(db)
            }
        }
    }

    func fetchBacklinks(for targetTitle: String) throws -> [UUID] {
        try dbWriter.read { db in
            let links = try PageLink.filter(Column("target_title") == targetTitle).fetchAll(db)
            return links.map { $0.sourceID }
        }
    }

    // MARK: - 向量存储 (Embeddings)

    func saveEmbedding(id: UUID, vector: [Float], modelName: String) throws {
        let entry = PageEmbedding(id: id, vector: vector, modelName: modelName)
        try dbWriter.write { db in
            try entry.save(db)
        }
    }

    func fetchAllEmbeddings() throws -> [UUID: [Float]] {
        try dbWriter.read { db in
            let records = try PageEmbedding.fetchAll(db)
            var dict: [UUID: [Float]] = [:]
            for record in records {
                dict[record.id] = record.vector
            }
            return dict
        }
    }

    // MARK: - 统计

    func count(type: PageType? = nil) throws -> Int {
        try dbWriter.read { db in
            if let type = type {
                return try WikiPage.filter(Column("type") == type.rawValue).fetchCount(db)
            }
            return try WikiPage.fetchCount(db)
        }
    }

    func deleteAll() throws {
        _ = try dbWriter.write { db in
            try WikiPage.deleteAll(db)
        }
    }
}

// MARK: - GRDB 关联定义

extension WikiPage {
    /// 定义 FTS5 关联，使用 rowid 进行连接
    @MainActor
    static let contentSnapshot = belongsTo(WikiPageFTS.self, using: ForeignKey(["rowid"], to: ["rowid"]))
}
