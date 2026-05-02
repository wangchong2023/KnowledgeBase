import SwiftUI

// MARK: - Potential Link Suggestion
struct PotentialLinkSuggestion: Identifiable {
    var id = UUID()
    let sourcePageID: UUID
    let sourceTitle: String
    let targetTitle: String
}

// MARK: - Lint Issue
struct LintIssue: Identifiable {
    var id = UUID()
    var severity: LintSeverity
    var type: IssueType = .generic
    var pageID: UUID?
    var message: String
    var suggestion: String
    
    enum IssueType {
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
