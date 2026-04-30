import SwiftUI

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
