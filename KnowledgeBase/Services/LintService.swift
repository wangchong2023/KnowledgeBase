import Foundation

// MARK: - Lint Service (Health Check)
/// 对知识库进行健康检查：断裂链接、孤立页面、存根页面、陈旧内容。
/// Returns issues without side effects — caller decides what to do with results.
final class LintService {
    
    /// Threshold (in days) after which an active page is considered stale.
    private static let stalePageThresholdDays = 30
    
    /// Run all lint checks and return the list of issues found.
    func runLint(pages: [WikiPage], linkService: LinkService) -> [LintIssue] {
        var issues: [LintIssue] = []

        // Check for orphan pages (no incoming links)
        for page in pages {
            let backs = linkService.backlinks(for: page.id, in: pages)
            if backs.isEmpty && page.type != .raw {
                issues.append(LintIssue(
                    severity: .warning,
                    pageID: page.id,
                    message: String(format: Localized.tr("lint.orphanPage"), page.title),
                    suggestion: String(format: Localized.tr("lint.orphanSuggestion"), page.title)
                ))
            }
        }

        // Check for broken wikilinks
        for page in pages {
            for link in page.outgoingLinks {
                if linkService.pageByTitle(link, in: pages) == nil {
                    issues.append(LintIssue(
                        severity: .error,
                        pageID: page.id,
                        message: String(format: Localized.tr("lint.brokenLink"), page.title, link),
                        suggestion: String(format: Localized.tr("lint.brokenLinkSuggestion"), link)
                    ))
                }
            }
        }

        // Check for stubs
        for page in pages where page.isStub && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                pageID: page.id,
                message: String(format: Localized.tr("lint.stubContent"), page.title),
                suggestion: Localized.tr("lint.stubSuggestion")
            ))
        }

        // Check for stale pages (not updated in 30 days)
        let staleThreshold = Calendar.current.date(byAdding: .day, value: -Self.stalePageThresholdDays, to: Date()) ?? Date()
        for page in pages where page.updated < staleThreshold && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                pageID: page.id,
                message: String(format: Localized.tr("lint.outdated"), page.title),
                suggestion: Localized.tr("lint.outdatedSuggestion")
            ))
        }

        return issues
    }
}
