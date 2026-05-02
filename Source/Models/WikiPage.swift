import Foundation

// MARK: - Character Extension for CJK
extension Character {
    var isCJKCharacter: Bool {
        let scalars = unicodeScalars
        return scalars.contains { scalar in
            // CJK Unified Ideographs and common CJK ranges
            (0x4E00...0x9FFF).contains(scalar.value) ||  // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) ||  // CJK Extension A
            (0x3000...0x303F).contains(scalar.value) ||  // CJK Symbols and Punctuation
            (0xFF00...0xFFEF).contains(scalar.value) ||  // Halfwidth and Fullwidth Forms
            (0x2E80...0x2EFF).contains(scalar.value) ||  // CJK Radicals Supplement
            (0x3040...0x309F).contains(scalar.value) ||  // Hiragana
            (0x30A0...0x30FF).contains(scalar.value) ||  // Katakana
            (0xAC00...0xD7AF).contains(scalar.value)     // Korean Syllables
        }
    }
}

// MARK: - Wiki Page
struct WikiPage: Identifiable, Codable, Hashable {
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
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsContent.substring(with: match.range(at: 1))
        }
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
    
    /// 语义缩放层级 (PM & UI 视角：根据视角深度动态展示)
    enum LODLevel {
        case macro    // 仅展示聚类点
        case normal   // 展示标题与链接
        case micro    // 展示内容摘要与元数据
    }
    
    func getLOD(for zoomScale: Double) -> LODLevel {
        if zoomScale < 0.5 { return .macro }
        if zoomScale > 2.0 { return .micro }
        return .normal
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
}
