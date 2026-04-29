import Foundation

// MARK: - Page Store Protocol
/// Abstraction layer allowing both PageStore (JSON) and SQLiteStore (SQL) to serve as data sources.
protocol AnyPageStore {
    var pages: [WikiPage] { get }
    @discardableResult
    func createPage(title: String, type: PageType, content: String, tags: [String]) -> WikiPage
    func updatePage(_ page: WikiPage)
}

// MARK: - Conform PageStore to protocol
extension PageStore: AnyPageStore {
    func createPage(title: String, type: PageType, content: String = "", tags: [String] = []) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags)
    }
}
// Note: SQLiteStore conformance is declared in SQLiteStore.swift to avoid circular dependency

// MARK: - Ingest Service (Knowledge Ingestion)
/// Handles raw content ingestion: creates source pages and auto-links existing concepts.
final class IngestService {
    /// Ingest raw content into the wiki by creating a new page and auto-linking known concepts.
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
