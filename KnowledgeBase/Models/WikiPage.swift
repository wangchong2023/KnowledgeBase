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
    var created: Date
    var updated: Date

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
        self.created = created
        self.updated = updated
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
