import SwiftUI

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
