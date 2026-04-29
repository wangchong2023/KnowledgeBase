import Foundation
import SQLite3

// MARK: - SQLite Store (Facade — Composes Core + Migrator + Seed Data)
/// Thin facade that composes SQLiteStoreCore, SQLiteMigrator, and KMSeedData.
/// All database operations delegate to SQLiteStoreCore.
final class SQLiteStore: ObservableObject {
    @Published var pages: [WikiPage] = []

    // MARK: - Sub-components
    private let core: SQLiteStoreCore
    private let migrator: SQLiteMigrator

    // MARK: - Callbacks
    var onLog: ((String, String, String) -> Void)?
    var onSaveNeeded: (() -> Void)?

    // MARK: - Init
    init() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dbPath = docsDir.appendingPathComponent("wikicraft.sqlite3")

        self.core = SQLiteStoreCore(dbPath: dbPath)
        self.migrator = SQLiteMigrator(core: core, docsDir: docsDir)

        core.open()
        core.createTables()
        migrator.migrateIfNeeded()
        loadAllPages()
    }

    deinit {
        core.close()
    }

    // MARK: - CRUD Operations
    @discardableResult
    func createPage(title: String, type: PageType, customIcon: String? = nil, content: String = "", tags: [String] = []) -> WikiPage {
        let page = WikiPage(
            title: title,
            type: type,
            customIcon: customIcon,
            content: content,
            tags: tags,
            status: content.isEmpty ? .stub : .active
        )

        core.insertPage(page)
        pages.append(page)

        onLog?(L.tr("logAction.create"), title, "\(L.tr("detail.pageType")): \(type.displayName)")
        return page
    }

    func updatePage(_ page: WikiPage) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            var updated = page
            updated.updated = Date()
            pages[index] = updated
            core.updatePage(updated)
            onLog?(L.tr("logAction.update"), page.title, "")
        }
    }

    func deletePage(_ page: WikiPage, clearSelectionIfNeeded: (UUID) -> Bool) {
        // Remove related references first
        for i in pages.indices {
            if pages[i].relatedPageIDs.contains(page.id) {
                var refPage = pages[i]
                refPage.relatedPageIDs.removeAll { $0 == page.id }
                core.updatePage(refPage)
                pages[i] = refPage
            }
        }

        core.deletePage(id: page.id)
        _ = clearSelectionIfNeeded(page.id)
        pages.removeAll { $0.id == page.id }

        onLog?(L.tr("logAction.delete"), page.title, "")
    }

    // MARK: - Lookup
    func pageByID(_ id: UUID) -> WikiPage? {
        pages.first { $0.id == id }
    }

    func pageByTitle(_ title: String) -> WikiPage? {
        let lower = title.lowercased()

        if let exact = core.selectPageByColumn("title", value: title.lowercased()) {
            return exact
        }

        return pages.first { page in
            page.aliases.contains { $0.lowercased() == lower }
        }
    }

    /// Full-text search across title, content, tags, aliases.
    func searchPages(query: String) -> [WikiPage] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return pages }

        var results: [WikiPage] = []
        var seenIDs = Set<UUID>()
        let queryLower = query.lowercased()

        for page in pages {
            let titleMatch = page.title.lowercased().contains(queryLower)
            let aliasMatch = page.aliases.contains { $0.lowercased().contains(queryLower) }
            let tagMatch = page.tags.contains { $0.lowercased().contains(queryLower) }
            let contentMatch = page.content.lowercased().contains(queryLower)

            if titleMatch || aliasMatch || tagMatch || contentMatch {
                if !seenIDs.contains(page.id) {
                    results.append(page)
                    seenIDs.insert(page.id)
                }
            }
        }

        return results
    }

    func pagesByType(_ type: PageType) -> [WikiPage] {
        pages.filter { $0.type == type }
    }

    func pagesByStatus(_ status: PageStatus) -> [WikiPage] {
        pages.filter { $0.status == status }
    }

    // MARK: - Statistics
    var totalPages: Int { pages.count }
    var entityCount: Int { pages.filter { $0.type == .entity }.count }
    var conceptCount: Int { pages.filter { $0.type == .concept }.count }
    var sourceCount: Int { pages.filter { $0.type == .source }.count }
    var stubCount: Int { pages.filter { $0.isStub }.count }
    var activeCount: Int { pages.filter { $0.status == .active }.count }
    var totalWords: Int { pages.reduce(0) { $0 + $1.wordCount } }

    // MARK: - Bulk Operations
    func replaceAllPages(_ newPages: [WikiPage]) {
        core.beginTransaction()
        core.deleteAllPages()
        for page in newPages {
            core.insertPage(page)
        }
        core.commitTransaction()
        pages = newPages
    }

    func removeAllPages() {
        core.deleteAllPages()
        pages = []
    }

    // MARK: - Load / Reload
    func loadAllPages() {
        pages = core.selectAllPages()
    }

    func reloadFromDisk() {
        loadAllPages()
        onSaveNeeded?()
    }

    // MARK: - Seed Default Content
    func seedDefaultContent(logAction: (String, String, String) -> Void) {
        for data in KMSeedData.pages {
            _ = createPage(
                title: data.title,
                type: data.type,
                content: data.content,
                tags: data.tags
            )
        }

        // Set up related page IDs after all pages are created
        for i in pages.indices {
            let page = pages[i]
            var relatedIDs: [UUID] = []
            for link in page.outgoingLinks {
                if let linked = pageByTitle(link), !relatedIDs.contains(linked.id) {
                    relatedIDs.append(linked.id)
                }
            }
            if !relatedIDs.isEmpty {
                pages[i].relatedPageIDs = relatedIDs
                core.updatePage(pages[i])
            }
        }
    }
}

// MARK: - AnyPageStore Conformance
extension SQLiteStore: AnyPageStore {
    func createPage(title: String, type: PageType, content: String = "", tags: [String] = []) -> WikiPage {
        createPage(title: title, type: type, customIcon: nil, content: content, tags: tags)
    }
}
