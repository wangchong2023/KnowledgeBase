// LintService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的“内容巡检”与“健康审计”服务（LintService），旨在通过多维度算法自动发现并标记知识库中的质量缺陷。
// 该服务作为知识维护层的核心组件，通过以下功能点确保知识库的长期活力与引用完整性：
// 1. 结构化漏洞检测：自动识别“孤岛页面”（无出入链）、“断裂链接”（指向缺失页面）及“循环引用”，维护图谱结构的拓扑严谨性。
// 2. 知识陈旧度分析：基于时间阈值追踪活跃内容的更新频率，及时提醒用户对存Stub页面或陈旧知识进行深度扩充与重构。
// 3. 量化健康评分模型：内置扣分制算法（根据严重程度分级），将复杂的审计结果转化为直观的健康得分与等级评价（优秀至差）。
// 4. 非破坏性审计流程：坚持“只检不改”的原则，仅生成合规性建议（Suggestion），将最终的决策权交还给用户或 AI 修复辅助。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，完善健康评分权重与巡检逻辑说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
