

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
        case .entity: return Localized.tr("type.entity")
        case .concept: return Localized.tr("type.concept")
        case .source: return Localized.tr("type.source")
        case .comparison: return Localized.tr("type.comparison")
        case .map: return Localized.tr("type.map")
        case .raw: return Localized.tr("type.raw")
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
        case .active: return Localized.tr("status.active")
        case .stub: return Localized.tr("status.stub")
        case .needsUpdate: return Localized.tr("status.needsUpdate")
        case .deprecated: return Localized.tr("status.deprecated")
        }
    }
    
    var colorName: String {
        switch self {
        case .active: return "green"
        case .stub: return "yellow"
        case .needsUpdate: return "orange"
        case .deprecated: return "red"
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
        case .high: return Localized.tr("confidence.high")
        case .medium: return Localized.tr("confidence.medium")
        case .low: return Localized.tr("confidence.low")
        }
    }
    
    var colorName: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "red"
        }
    }
}
