// WikiPage.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了知识管理系统的核心数据实体模型（WikiPage），承载了知识点的全量元数据与生命周期逻辑。
// 作为系统的原子级信息单元，该模型通过以下功能点保障了知识库的稳健性与可扩展性：
// 1. 持久化与同步能力：集成了 GRDB 协议以支持高性能本地存储，并内置 Lamport 逻辑时钟实现多端同步时的冲突解决（LWW 策略）。
// 2. 知识关系建模：通过 WikiLinkProcessor 自动提取文档内的双向引用关系，并支持手动建立相关页面（Related Pages）的语义关联。
// 3. 多维元数据审计：提供字数统计（支持中英混排）、隐私敏感度判定、状态追踪及溯源链接（Source URL）管理。
// 4. 灵活的呈现逻辑：根据页面类型自动适配图标与存储路径，支持用户自定义 SF Symbol 以实现个性化的视觉分类。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，将链接解析逻辑解耦至 WikiLinkProcessor
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import GRDB

// MARK: - Wiki Page
/// 知识管理系统核心数据模型
struct WikiPage: Identifiable, Codable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName: String = "pages"
    
    enum CodingKeys: String, CodingKey {
        case id, title, type, content, aliases, tags, status, confidence, sources, created, updated
        case customIcon = "custom_icon"
        case relatedPageIDs = "related_page_ids"
        case isPinned = "is_pinned"
        case contentHash = "content_hash"
        case sourceURL = "source_url"
        case rawTextSnippet = "raw_snippet"
        case lamportTimestamp = "lamport_timestamp"
    }
    
    var id: UUID
    var title: String
    var type: PageType
    var customIcon: String?   // User-selected SF Symbol, nil = use type.icon
    var content: String
    var aliases: [String]
    var tags: [String]
    var status: PageStatus
    var confidence: Confidence
    var sources: [String]  // references to raw source IDs
    var relatedPageIDs: [UUID]
    var isPinned: Bool
    var contentHash: String?
    var created: Date
    var updated: Date
    // MARK: - 分布式冲突解决 (LWW 策略)
    var lamportTimestamp: Int64 // 逻辑时钟，用于解决多端同步冲突
    
    // MARK: - 溯源字段 (Karpathy 模式)
    var sourceURL: String?      // 原始资料链接 (网页或 YouTube)
    var rawTextSnippet: String? // 原始资料片段，用于校验

    /// Display icon: customIcon if set, otherwise type.icon
    var displayIcon: String {
        customIcon ?? type.icon
    }

    init(
        id: UUID = UUID(),
        title: String,
        type: PageType = .concept,
        customIcon: String? = nil,
        content: String = "",
        aliases: [String] = [],
        tags: [String] = [],
        status: PageStatus = .active,
        confidence: Confidence = .medium,
        sources: [String] = [],
        relatedPageIDs: [UUID] = [],
        isPinned: Bool = false,
        contentHash: String? = nil,
        sourceURL: String? = nil,
        rawTextSnippet: String? = nil,
        lamportTimestamp: Int64? = nil,
        created: Date = Date(),
        updated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.customIcon = customIcon
        self.content = content
        self.aliases = aliases
        self.tags = tags
        self.status = status
        self.confidence = confidence
        self.sources = sources
        self.relatedPageIDs = relatedPageIDs
        self.isPinned = isPinned
        self.contentHash = contentHash
        self.sourceURL = sourceURL
        self.rawTextSnippet = rawTextSnippet
        self.lamportTimestamp = lamportTimestamp ?? Int64(created.timeIntervalSince1970 * 1000)
        self.created = created
        self.updated = updated
    }
    
    /// 执行 LWW (Last Write Wins) 冲突合并
    /// - Parameter remote: 远程或同步过来的版本
    /// - Returns: 合并后的最终版本
    func merge(with remote: WikiPage) -> WikiPage {
        // 核心规则：时间戳大的胜出
        if remote.lamportTimestamp > self.lamportTimestamp {
            return remote
        } else if remote.lamportTimestamp < self.lamportTimestamp {
            return self
        } else {
            // 时间戳一致时，以更新时间为准
            return remote.updated > self.updated ? remote : self
        }
    }
    
    // Extract [[wikilinks]] from content
    var outgoingLinks: [String] {
        WikiLinkProcessor.extractOutgoingLinks(from: content)
    }
    
    var wordCount: Int {
        // Support both Chinese and English word counting
        // Chinese: count CJK characters individually; English: count by spaces
        var count = 0
        var inEnglishWord = false
        
        for char in content {
            if char.isCJKCharacter {
                if inEnglishWord {
                    count += 1
                    inEnglishWord = false
                }
                count += 1
            } else if char.isLetter || char.isNumber {
                inEnglishWord = true
            } else if inEnglishWord {
                count += 1
                inEnglishWord = false
            }
        }
        if inEnglishWord { count += 1 }
        return count
    }
    
    var isStub: Bool {
        content.count < 100
    }
    
    
    var folderName: String {
        switch type {
        case .entity: return "entities"
        case .concept: return "concepts"
        case .source: return "sources"
        case .comparison: return "comparisons"
        case .map: return "maps"
        case .raw: return "raw"
        }
    }

    /// 隐私敏感判定
    var isPrivate: Bool {
        tags.contains("private") || content.contains("#private")
    }
}
