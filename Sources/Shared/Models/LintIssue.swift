// LintIssue.swift
//
// 作者: Wang Chong
// 功能说明: struct PotentialLinkSuggestion
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import SwiftUI

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
        case generic = "generic"
        case brokenLink = "brokenLink"
        case orphan = "orphan"
        case island = "island"
        case cycle = "cycle"
        case stub = "stub"
        case stale = "stale"
        
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
        case error = "error"
        case warning = "warning"
        case info = "info"

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
