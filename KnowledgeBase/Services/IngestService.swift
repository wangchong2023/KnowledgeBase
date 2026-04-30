import Foundation

// MARK: - Page Store Protocol
/// Abstraction layer allowing different store implementations to serve as data sources.
/// SQLiteStore is the sole implementation; PageStore was removed (JSON-based, unused).
protocol AnyPageStore {
    var pages: [WikiPage] { get }
    @discardableResult
    func createPage(title: String, type: PageType, content: String, tags: [String]) -> WikiPage
    func updatePage(_ page: WikiPage)
}
// Note: SQLiteStore conformance is declared in SQLiteStore.swift to avoid circular dependency

// MARK: - Ingest Service (Knowledge Ingestion)
/// Handles raw content ingestion: creates source pages and auto-links existing concepts.
final class IngestService {
    /// 将原始内容摄入知识库：创建新页面并自动链接已知概念。
    /// - Returns: The created page (with auto-linked content).
    func ingestRawContent(
        title: String,
        content: String,
        type: PageType = .source,
        pageStore: any AnyPageStore
    ) -> WikiPage {
        // Create raw source page
        let rawPage = pageStore.createPage(
            title: title,
            type: type,
            content: content,
            tags: ["ingested"]
        )

        // Auto-extract potential concept links from content
        let concepts = extractConcepts(from: content, pages: pageStore.pages)
        var updatedContent = rawPage.content

        for concept in concepts {
            updatedContent = updatedContent.replacingOccurrences(
                of: concept,
                with: "[[\(concept)]]"
            )
        }

        var page = rawPage
        page.content = updatedContent
        pageStore.updatePage(page)

        return page
    }

    /// Extract existing page titles mentioned in the given content.
    func extractConcepts(from content: String, pages: [WikiPage]) -> [String] {
        var found: [String] = []
        for page in pages {
            if content.lowercased().contains(page.title.lowercased()) {
                found.append(page.title)
            }
        }
        return found
    }
}
