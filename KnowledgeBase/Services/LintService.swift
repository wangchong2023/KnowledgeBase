import Foundation

// MARK: - Lint Service (Health Check)
/// Runs health checks on the wiki: broken links, orphan pages, stubs, stale content.
/// Returns issues without side effects — caller decides what to do with results.
final class LintService {
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
                    message: String(format: L.tr("lint.orphanPage"), page.title),
                    suggestion: String(format: L.tr("lint.orphanSuggestion"), page.title)
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
                        message: String(format: L.tr("lint.brokenLink"), page.title, link),
                        suggestion: String(format: L.tr("lint.brokenLinkSuggestion"), link)
                    ))
                }
            }
        }

        // Check for stubs
        for page in pages where page.isStub && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                pageID: page.id,
                message: String(format: L.tr("lint.stubContent"), page.title),
                suggestion: L.tr("lint.stubSuggestion")
            ))
        }

        // Check for stale pages (not updated in 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        for page in pages where page.updated < thirtyDaysAgo && page.status == .active {
            issues.append(LintIssue(
                severity: .info,
                pageID: page.id,
                message: String(format: L.tr("lint.outdated"), page.title),
                suggestion: L.tr("lint.outdatedSuggestion")
            ))
        }

        return issues
    }
}
