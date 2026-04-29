import SwiftUI
import Combine

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

// MARK: - Page Type
enum PageType: String, Codable, CaseIterable, Identifiable {
    case entity = "entity"
    case concept = "concept"
    case source = "source"
    case comparison = "comparison"
    case map = "map"
    case raw = "raw"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .entity: return L.tr("type.entity")
        case .concept: return L.tr("type.concept")
        case .source: return L.tr("type.source")
        case .comparison: return L.tr("type.comparison")
        case .map: return L.tr("type.map")
        case .raw: return L.tr("type.raw")
        }
    }
    
    var icon: String {
        switch self {
        case .entity: return "person.text.rectangle.fill"
        case .concept: return "lightbulb.fill"
        case .source: return "doc.richtext.fill"
        case .comparison: return "arrow.left.arrow.right.circle.fill"
        case .map: return "map.fill"
        case .raw: return "doc.plaintext.fill"
        }
    }
    
    var color: String {
        switch self {
        case .entity: return "blue"
        case .concept: return "purple"
        case .source: return "green"
        case .comparison: return "orange"
        case .map: return "red"
        case .raw: return "gray"
        }
    }
}

// MARK: - Page Status
enum PageStatus: String, Codable, CaseIterable {
    case active = "active"
    case stub = "stub"
    case needsUpdate = "needs-update"
    case deprecated = "deprecated"
    
    var displayName: String {
        switch self {
        case .active: return L.tr("status.active")
        case .stub: return L.tr("status.stub")
        case .needsUpdate: return L.tr("status.needsUpdate")
        case .deprecated: return L.tr("status.deprecated")
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .stub: return .yellow
        case .needsUpdate: return .orange
        case .deprecated: return .red
        }
    }
}

// MARK: - Confidence Level
enum Confidence: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return L.tr("confidence.high")
        case .medium: return L.tr("confidence.medium")
        case .low: return L.tr("confidence.low")
        }
    }
    
    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .red
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

// MARK: - Log Entry
struct LogEntry: Identifiable, Codable {
    var id: UUID
    var action: String
    var target: String
    var details: String
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        action: String,
        target: String,
        details: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Lint Issue
struct LintIssue: Identifiable {
    var id = UUID()
    var severity: LintSeverity
    var pageID: UUID?
    var message: String
    var suggestion: String
    
    enum LintSeverity {
        case error, warning, info
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
}

// MARK: - Graph Node
struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let type: PageType
    var position: CGPoint
    var isHighlighted: Bool = false
}

// MARK: - Graph Edge
struct GraphEdge: Identifiable {
    let id = UUID()
    let source: UUID
    let target: UUID
}
