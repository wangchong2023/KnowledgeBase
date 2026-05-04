// LintService.swift
//
// 作者: Wang Chong
// 功能说明: 对知识库进行健康检查：断裂链接、孤立页面、存根页面、陈旧内容。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import SwiftUI

// MARK: - Lint Service (Health Check)
/// 对知识库进行健康检查：断裂链接、孤立页面、存根页面、陈旧内容。
/// Returns issues without side effects — caller decides what to do with results.
final class LintService: @unchecked Sendable {
    
    /// 知识库健康等级
    enum HealthLevel: String, CaseIterable, Sendable {
        case excellent, good, fair, poor
        
        var title: String { L10n.Lint.tr("health.\(self.rawValue)") }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
    
    /// Threshold (in days) after which an active page is considered stale.
    private static let stalePageThresholdDays = 30
    
    /// Run all lint checks and return the list of issues found.
    func runLint(pages: [WikiPage], linkService: LinkService) async -> [LintIssue] {
        var issues: [LintIssue] = []

        // Check for island pages (no incoming AND no outgoing links)
        for page in pages {
            let backs = await linkService.backlinks(for: page.id, in: pages)
            if backs.isEmpty && page.outgoingLinks.isEmpty && page.type != .raw {
                issues.append(LintIssue(
                    severity: .warning,
                    type: .island,
                    pageID: page.id,
                    message: String(format: L10n.Lint.tr("islandMessage"), page.title),
                    suggestion: L10n.Lint.tr("islandSuggestion")
                ))
            } else if backs.isEmpty && page.type != .raw {
                // Legacy orphan check (no incoming links only)
                issues.append(LintIssue(
                    severity: .info,
                    type: .orphan,
                    pageID: page.id,
                    message: String(format: L10n.Lint.tr("orphanPage"), page.title),
                    suggestion: String(format: L10n.Lint.tr("orphanSuggestion"), page.title)
                ))
            }
        }

        // Check for simple circular references (A -> B -> A)
        for pageA in pages {
            for linkTitle in pageA.outgoingLinks {
                if let pageB = await linkService.pageByTitle(linkTitle, in: pages) {
                    if pageB.outgoingLinks.contains(where: { $0.lowercased() == pageA.title.lowercased() }) {
                        issues.append(LintIssue(
                            severity: .info,
                            type: .cycle,
                            pageID: pageA.id,
                            message: String(format: L10n.Lint.tr("cycleMessage"), pageA.title, pageB.title),
                            suggestion: L10n.Lint.tr("cycleSuggestion")
                        ))
                    }
                }
            }
        }

        // Check for broken wikilinks
        for page in pages {
            for link in page.outgoingLinks {
                if await linkService.pageByTitle(link, in: pages) == nil {
                    issues.append(LintIssue(
                        severity: .error,
                        type: .brokenLink,
                        pageID: page.id,
                        message: String(format: L10n.Lint.tr("brokenLink"), page.title, link),
                        suggestion: String(format: L10n.Lint.tr("brokenLinkSuggestion"), link)
                    ))
                }
            }
        }

        // Check for stubs
        for page in pages where page.isStub && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                type: .stub,
                pageID: page.id,
                message: String(format: L10n.Lint.tr("stubContent"), page.title),
                suggestion: L10n.Lint.tr("stubSuggestion")
            ))
        }

        // Check for stale pages (not updated in 30 days)
        let staleThreshold = Calendar.current.date(byAdding: .day, value: -Self.stalePageThresholdDays, to: Date()) ?? Date()
        for page in pages where page.updated < staleThreshold && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                type: .stale,
                pageID: page.id,
                message: String(format: L10n.Lint.tr("outdated"), page.title),
                suggestion: L10n.Lint.tr("outdatedSuggestion")
            ))
        }

        return issues
    }

    /// 根据检查结果计算健康评分与等级
    func calculateHealthMetrics(issues: [LintIssue]) -> (score: Int, level: HealthLevel) {
        let errorCount = issues.filter { $0.severity == .error }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        
        // 扣分制：错误 -10，警告 -5，提示 -2
        let deduction = (errorCount * 10) + (warningCount * 5) + (infoCount * 2)
        let score = max(0, 100 - deduction)
        
        let level: HealthLevel
        if score >= 90 { level = .excellent }
        else if score >= 75 { level = .good }
        else if score >= 50 { level = .fair }
        else { level = .poor }
        
        return (score, level)
    }
}
