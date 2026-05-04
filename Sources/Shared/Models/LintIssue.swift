

import Foundation

// MARK: - Potential Link Suggestion
struct PotentialLinkSuggestion: Identifiable, Codable, Sendable {
    var id = UUID()
    let sourcePageID: UUID
    let sourceTitle: String
    let targetTitle: String
}

// MARK: - Lint Issue
struct LintIssue: Identifiable, Codable, Sendable {
    var id = UUID()
    var severity: LintSeverity
    var type: IssueType = .generic
    var pageID: UUID?
    var message: String
    var suggestion: String
    
    enum IssueType: String, Codable, Sendable {
        case generic
        case brokenLink
        case orphan
        case island
        case cycle
        case stub
        case stale
        
        var icon: String {
            switch self {
            case .brokenLink: return "link.badge.minus"
            case .orphan: return "person.crop.circle.badge.questionmark"
            case .island: return "leaf.fill"
            case .cycle: return "arrow.2.squarepath"
            case .stub: return "doc.append"
            case .stale: return "clock.arrow.circlepath"
            default: return "sparkles"
            }
        }
    }

    enum LintSeverity: String, Codable, Sendable {
        case error, warning, info
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var colorName: String {
            switch self {
            case .error: return "red"
            case .warning: return "orange"
            case .info: return "blue"
            }
        }
    }
}
