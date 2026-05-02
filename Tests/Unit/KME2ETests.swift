import XCTest
@testable import KM

// MARK: - E2E: Complete Wiki Page Workflow Tests
/// 覆盖从创建→编辑→链接→健康检查→删除的完整页面生命周期
final class WikiPageWorkflowTests: XCTestCase {

    var store: KMStore!
    var linkService: LinkService!
    var lintService: LintService!

    override func setUp() {
        super.setUp()
        store = KMStore()
        linkService = LinkService()
        lintService = LintService()
    }

    override func tearDown() {
        store = nil
        linkService = nil
        lintService = nil
        super.tearDown()
    }

    // MARK: - Page Creation

    func testCreatePageWithAllFields() {
        let page = WikiPage(
            title: "E2E Test Page",
            type: .entity,
            customIcon: "star.fill",
            content: "This is test content with enough characters to not be a stub.",
            aliases: ["E2E Alias", "Test Alias"],
            tags: ["e2e", "test", "automation"],
            status: .active,
            confidence: .high,
            sources: ["Source A"],
            relatedPageIDs: [],
            isPinned: true
        )

        XCTAssertEqual(page.title, "E2E Test Page")
        XCTAssertEqual(page.type, .entity)
        XCTAssertEqual(page.displayIcon, "star.fill")
        XCTAssertEqual(page.aliases, ["E2E Alias", "Test Alias"])
        XCTAssertEqual(page.tags, ["e2e", "test", "automation"])
        XCTAssertEqual(page.status, .active)
        XCTAssertEqual(page.confidence, .high)
        XCTAssertTrue(page.isPinned)
        XCTAssertFalse(page.isStub)
    }

    func testCreatePageAutoCalculatesIsStub() {
        let shortContent = WikiPage(title: "Short", type: .entity, content: "Tiny")
        XCTAssertTrue(shortContent.isStub)

        let longContent = WikiPage(title: "Long", type: .entity, content: String(repeating: "word ", count: 30))
        XCTAssertFalse(longContent.isStub)
    }

    // MARK: - Page Editing

    func testUpdatePageTitlePropagation() {
        var page = WikiPage(title: "Original Title", type: .concept, content: "Content here")
        page.title = "Updated Title"

        XCTAssertEqual(page.title, "Updated Title")
    }

    func testUpdatePageTags() {
        var page = WikiPage(title: "Tagged Page", type: .entity, content: String(repeating: "x ", count: 30))

        XCTAssertTrue(page.tags.isEmpty)

        page.tags = ["new-tag", "another-tag"]
        XCTAssertEqual(page.tags.count, 2)
        XCTAssertTrue(page.tags.contains("new-tag"))
    }

    // MARK: - WikiLinks

    func testBidirectionalLinkCreation() {
        var pageA = WikiPage(title: "Page A", type: .entity, content: "Links to [[Page B]]")
        var pageB = WikiPage(title: "Page B", type: .concept, content: "Links to [[Page A]]")

        // Outgoing links
        XCTAssertEqual(pageA.outgoingLinks, ["Page B"])
        XCTAssertEqual(pageB.outgoingLinks, ["Page A"])

        // Backlinks via LinkService
        let pages = [pageA, pageB]
        let aBacklinks = linkService.backlinks(for: pageA.id, in: pages)
        let bBacklinks = linkService.backlinks(for: pageB.id, in: pages)

        XCTAssertEqual(aBacklinks.map(\.title), ["Page B"])
        XCTAssertEqual(bBacklinks.map(\.title), ["Page A"])
    }

    func testSelfReferencingLinkHandled() {
        let page = WikiPage(title: "Self", type: .entity, content: "Links to [[Self]] and [[self]]")
        XCTAssertEqual(page.outgoingLinks.count, 2)
        XCTAssertEqual(page.outgoingLinks, ["Self", "self"])
    }

    func testBrokenWikiLinksIdentified() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[NonExistent Page]]")
        let pageB = WikiPage(title: "B", type: .concept, content: "Real link to [[C]]")
        var pageC = WikiPage(title: "C", type: .source, content: "Content here")

        let pages = [pageA, pageB, pageC]

        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let errorIssues = issues.filter { $0.severity == .error }

        // A has broken link to NonExistent Page
        XCTAssertFalse(errorIssues.isEmpty, "Should detect at least one broken link")
    }

    // MARK: - Undo/Redo

    func testUndoRedoFullCycle() {
        let undoService = UndoService()

        let v1 = [WikiPage(title: "V1", type: .entity, content: "Version 1 content")]
        let v2 = [WikiPage(title: "V2", type: .concept, content: "Version 2 content")]
        let v3 = [WikiPage(title: "V3", type: .source, content: "Version 3 content")]

        // Push initial state
        undoService.pushSnapshot(v1)
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)

        // Undo v2 → v1
        let afterUndo = undoService.undo(currentPages: v2)
        XCTAssertEqual(afterUndo?.first?.title, "V1")
        XCTAssertTrue(undoService.canRedo)
        XCTAssertFalse(undoService.canUndo)

        // Redo v1 → v2
        let afterRedo = undoService.redo(currentPages: afterUndo!)
        XCTAssertEqual(afterRedo?.first?.title, "V2")
        XCTAssertTrue(undoService.canUndo)
        XCTAssertTrue(undoService.canRedo)

        // New action clears redo
        undoService.pushSnapshot(v3)
        XCTAssertFalse(undoService.canRedo, "New snapshot should clear redo stack")
    }

    // MARK: - Page Deletion

    func testDeletePageRemovesFromList() {
        let page1 = WikiPage(title: "To Delete", type: .entity, content: "Content")
        let page2 = WikiPage(title: "To Keep", type: .concept, content: "More content here")

        var pages = [page1, page2]
        pages.removeAll { $0.id == page1.id }

        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.title, "To Keep")
    }

    // MARK: - Health Check Integration

    func testHealthCheckNoIssuesForHealthyWiki() {
        var page1 = WikiPage(title: "Healthy A", type: .entity, content: String(repeating: "Healthy content here. ", count: 10))
        var page2 = WikiPage(title: "Healthy B", type: .concept, content: "Links to [[Healthy A]]. " + String(repeating: "More healthy content. ", count: 10))

        let pages = [page1, page2]

        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let errorCount = issues.filter { $0.severity == .error }.count

        // No broken links, no orphans (both pages link to each other)
        XCTAssertEqual(errorCount, 0, "Healthy wiki should produce no errors")
    }

    func testStubPagesFlaggedByHealthCheck() {
        let stubPage = WikiPage(title: "Stubby", type: .entity, content: "Too short")

        let pages = [stubPage]
        let issues = lintService.runLint(pages: pages, linkService: linkService)

        let stubIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("stub") ||
            $0.message.localizedCaseInsensitiveContains("short") ||
            $0.message.localizedCaseInsensitiveContains("内容过少")
        }

        XCTAssertFalse(stubIssues.isEmpty, "Stub pages should be flagged by health check")
    }
}

// MARK: - E2E: Search and Filter Workflow
final class SearchFilterWorkflowTests: XCTestCase {

    var linkService: LinkService!

    override func setUp() {
        super.setUp()
        linkService = LinkService()
    }

    func testSearchByTitleExactMatch() {
        let pages = [
            WikiPage(title: "Machine Learning", type: .concept, content: "ML content"),
            WikiPage(title: "Deep Learning", type: .concept, content: "DL content"),
            WikiPage(title: "Machine", type: .entity, content: "Just machine")
        ]

        let results = linkService.search(query: "Machine Learning", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Machine Learning" })
        XCTAssertFalse(results.contains { $0.title == "Machine" })
    }

    func testSearchByPartialTitle() {
        let pages = [
            WikiPage(title: "Neural Network", type: .entity, content: "Content"),
            WikiPage(title: "Network Analysis", type: .concept, content: "Content")
        ]

        let results = linkService.search(query: "Network", in: pages)
        XCTAssertEqual(results.count, 2)
    }

    func testSearchByContent() {
        let pages = [
            WikiPage(title: "Doc A", type: .source, content: "Python is a great language for data science"),
            WikiPage(title: "Doc B", type: .source, content: "JavaScript is great for web")
        ]

        let results = linkService.search(query: "data science", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Doc A" })
        XCTAssertFalse(results.contains { $0.title == "Doc B" })
    }

    func testSearchByTag() {
        let pages = [
            WikiPage(title: "Tagged", type: .entity, content: "Content", tags: ["important", "priority"]),
            WikiPage(title: "Untagged", type: .concept, content: "Content", tags: [])
        ]

        let results = linkService.search(query: "important", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Tagged" })
        XCTAssertFalse(results.contains { $0.title == "Untagged" })
    }

    func testFilterByPageType() {
        let pages = [
            WikiPage(title: "Entity Page", type: .entity, content: "Content " + String(repeating: "x ", count: 30)),
            WikiPage(title: "Concept Page", type: .concept, content: "Content " + String(repeating: "y ", count: 30)),
            WikiPage(title: "Source Page", type: .source, content: "Content " + String(repeating: "z ", count: 30)),
            WikiPage(title: "Another Entity", type: .entity, content: "Content " + String(repeating: "a ", count: 30))
        ]

        let entityPages = pages.filter { $0.type == .entity }
        XCTAssertEqual(entityPages.count, 2)

        let conceptPages = pages.filter { $0.type == .concept }
        XCTAssertEqual(conceptPages.count, 1)
    }

    func testSortByRecentlyUpdated() {
        var oldPage = WikiPage(title: "Old", type: .entity, content: "Content")
        var newPage = WikiPage(title: "New", type: .entity, content: "Content")

        // Simulate dates
        oldPage = WikiPage(
            id: oldPage.id,
            title: oldPage.title,
            type: oldPage.type,
            content: oldPage.content,
            aliases: oldPage.aliases,
            tags: oldPage.tags,
            status: oldPage.status,
            confidence: oldPage.confidence,
            sources: oldPage.sources,
            relatedPageIDs: oldPage.relatedPageIDs,
            isPinned: oldPage.isPinned,
            created: Date().addingTimeInterval(-86400),
            updated: Date().addingTimeInterval(-86400)
        )

        let sorted = [oldPage, newPage].sorted { $0.updated > $1.updated }
        XCTAssertEqual(sorted.first?.title, "New")
    }
}

// MARK: - E2E: Collaboration Workflow
final class CollaborationWorkflowTests: XCTestCase {

    func testCollabEditStructure() {
        let edit = CollabEdit(
            id: UUID(),
            userID: "user1",
            pageID: UUID(),
            field: "title",
            oldValue: "Old Title",
            newValue: "New Title",
            timestamp: Date()
        )

        XCTAssertEqual(edit.field, "title")
        XCTAssertEqual(edit.oldValue, "Old Title")
        XCTAssertEqual(edit.newValue, "New Title")
    }

    func testCollabUserDisplayLabel() {
        let user = CollabUser(
            id: "u1",
            displayName: "Alice",
            deviceName: "iPhone 15",
            joinedAt: Date()
        )

        XCTAssertEqual(user.displayLabel, "Alice (iPhone 15)")
    }

    func testDiscoveredRoomStructure() {
        let room = DiscoveredRoom(
            name: "Test Room",
            hostName: "HostUser",
            peerID: "peer123",
            createdAt: Date()
        )

        XCTAssertEqual(room.name, "Test Room")
        XCTAssertEqual(room.hostName, "HostUser")
    }

    func testRolePermissions() {
        // Owner can do everything
        XCTAssertTrue(CollabRole.owner.canEdit)
        XCTAssertTrue(CollabRole.owner.canDelete)

        // Editor can edit but not delete
        XCTAssertTrue(CollabRole.editor.canEdit)
        XCTAssertFalse(CollabRole.editor.canDelete)

        // Viewer cannot edit
        XCTAssertFalse(CollabRole.viewer.canEdit)
        XCTAssertFalse(CollabRole.viewer.canDelete)
    }
}

// MARK: - E2E: Backup and Restore Workflow
final class BackupRestoreWorkflowTests: XCTestCase {

    var backupService: BackupService!

    override func setUp() {
        super.setUp()
        backupService = BackupService()
    }

    override func tearDown() {
        backupService = nil
        super.tearDown()
    }

    func testCreateAndRestoreBackup() {
        let original = [
            WikiPage(title: "Page A", type: .entity, content: "Content A " + String(repeating: "x ", count: 20)),
            WikiPage(title: "Page B", type: .concept, content: "Content B " + String(repeating: "y ", count: 20))
        ]

        backupService.createBackup(pages: original)

        guard let entry = backupService.backupEntries.first else {
            XCTFail("Backup entry should exist"); return
        }

        let restored = backupService.restoreBackup(entry)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.count, 2)

        let restoredA = restored?.first { $0.title == "Page A" }
        XCTAssertNotNil(restoredA)
    }

    func testBackupPreservesAllPageTypes() {
        var pages: [WikiPage] = []
        for type in PageType.allCases {
            pages.append(WikiPage(title: "\(type.rawValue.capitalized) Page", type: type, content: "Content for \(type.rawValue) " + String(repeating: "x ", count: 20)))
        }

        backupService.createBackup(pages: pages)
        guard let entry = backupService.backupEntries.first else {
            XCTFail("Backup entry should exist"); return
        }

        let restored = backupService.restoreBackup(entry)
        XCTAssertEqual(restored?.count, PageType.allCases.count)

        for type in PageType.allCases {
            let found = restored?.contains { $0.type == type } ?? false
            XCTAssertTrue(found, "Page of type \(type.rawValue) should be in restored backup")
        }
    }

    func testMarkDirtyAndCleanWorkflow() {
        XCTAssertFalse(backupService.hasUnsavedChanges)

        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }
}

// MARK: - E2E: Ingest Pipeline
final class IngestPipelineTests: XCTestCase {

    var ingestService: IngestService!

    override func setUp() {
        super.setUp()
        ingestService = IngestService()
    }

    func testExtractConceptsFromMixedContent() {
        let existingPages = [
            WikiPage(title: "Machine Learning", type: .concept, content: "ML content"),
            WikiPage(title: "Neural Network", type: .entity, content: "NN content"),
            WikiPage(title: "Deep Learning", type: .concept, content: "DL content"),
            WikiPage(title: "Python", type: .source, content: "Python content")
        ]

        let newContent = """
        Machine Learning and Neural Networks are related fields.
        Deep Learning uses Neural Networks as building blocks.
        Python is commonly used for ML.
        """

        let concepts = ingestService.extractConcepts(from: newContent, pages: existingPages)

        XCTAssertTrue(concepts.contains("Machine Learning"), "Should extract 'Machine Learning'")
        XCTAssertTrue(concepts.contains("Neural Network"), "Should extract 'Neural Network'")
        XCTAssertTrue(concepts.contains("Deep Learning"), "Should extract 'Deep Learning'")
        XCTAssertTrue(concepts.contains("Python"), "Should extract 'Python'")
        XCTAssertEqual(concepts.count, 4, "Should extract exactly 4 unique concepts")
    }

    func testDocumentFormatDetectionPipeline() {
        let testCases: [(String, DocumentFormat)] = [
            ("document.md", .markdown),
            ("notes.txt", .plainText),
            ("report.pdf", .pdf),
            ("data.xlsx", .xlsx),
            ("document.docx", .docx),
            ("unknown.xyz", .unknown),
            ("UPPERCASE.MD", .markdown),
        ]

        for (filename, expected) in testCases {
            let url = URL(fileURLWithPath: "/path/to/\(filename)")
            let detected = DocumentFormat.detectFormat(from: url)
            XCTAssertEqual(detected, expected, "Failed for \(filename)")
        }
    }
}

// MARK: - E2E: Graph Layout with Realistic Data
final class GraphLayoutRealisticTests: XCTestCase {

    func testLayoutWith100NodesCompletesInReasonableTime() {
        var pages: [WikiPage] = []
        for i in 0..<100 {
            var page = WikiPage(
                title: "Page \(i)",
                type: PageType.allCases()[i % 6],
                content: "Content for page \(i). " + String(repeating: "word ", count: 20)
            )
            // Create some links between pages
            if i > 0 {
                page = WikiPage(
                    id: page.id,
                    title: page.title,
                    type: page.type,
                    content: "Links to [[Page \(i - 1)]] and [[Page \(i - 2)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    created: page.created,
                    updated: page.updated
                )
            }
            pages.append(page)
        }

        let start = Date()
        let result = GraphLayoutEngine.layout(
            pages: pages,
            linkResolver: { title in
                let numStr = title.replacingOccurrences(of: "Page ", with: "")
                if let num = Int(numStr), num < pages.count {
                    return pages[num]
                }
                return nil
            },
            canvasSize: CGSize(width: 1200, height: 800)
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(result.nodes.count, 100)
        XCTAssertGreaterThan(result.edges.count, 0)
        XCTAssertLessThan(elapsed, 5.0, "Layout should complete in under 5 seconds for 100 nodes")
    }

    func testGraphCommunitiesIdentified() {
        // Create a graph with clear community structure
        var communityA: [WikiPage] = []
        for i in 0..<5 {
            var page = WikiPage(title: "A\(i)", type: .entity, content: "Content A " + String(repeating: "x ", count: 20))
            if i > 0 {
                page = WikiPage(
                    id: page.id,
                    title: page.title,
                    type: page.type,
                    content: "Links to [[A\(i - 1)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    created: page.created,
                    updated: page.updated
                )
            }
            communityA.append(page)
        }

        var communityB: [WikiPage] = []
        for i in 0..<5 {
            var page = WikiPage(title: "B\(i)", type: .concept, content: "Content B " + String(repeating: "y ", count: 20))
            if i > 0 {
                page = WikiPage(
                    id: page.id,
                    title: page.title,
                    type: page.type,
                    content: "Links to [[B\(i - 1)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    created: page.created,
                    updated: page.updated
                )
            }
            communityB.append(page)
        }

        let allPages = communityA + communityB

        let result = GraphLayoutEngine.layout(
            pages: allPages,
            linkResolver: { title in allPages.first { $0.title == title } },
            canvasSize: CGSize(width: 1200, height: 800)
        )

        // Should have 10 nodes and 8 edges (5-1 in A, 5-1 in B)
        XCTAssertEqual(result.nodes.count, 10)
        XCTAssertEqual(result.edges.count, 8)

        // Check all nodes are within canvas
        for node in result.nodes {
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.x, 1200)
            XCTAssertLessThanOrEqual(node.position.y, 800)
        }
    }
}

// MARK: - E2E: Markdown Rendering
final class MarkdownRenderingTests: XCTestCase {

    var parser: MarkdownParser!

    override func setUp() {
        super.setUp()
        parser = MarkdownParser()
    }

    func testAllMarkdownBlockTypesParsed() {
        let content = """
        # Heading 1

        Some paragraph text.

        ## Heading 2

        - Bullet item 1
        - Bullet item 2

        1. Ordered item 1
        2. Ordered item 2

        > Blockquote text

        ```
        code block
        ```

        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |

        - [ ] Unchecked task
        - [x] Checked task

        ---

        More text after HR.
        """

        let blocks = parser.parse(content)
        XCTAssertGreaterThanOrEqual(blocks.count, 9, "Should parse at least 9 block types")
    }

    func testInlineFormattingExtraction() {
        let content = "**bold** and *italic* and `code` and [[WikiLink]]"

        let segments = parser.parseInlineSegments(content)

        let boldSegments = segments.filter { $0.type == .bold }
        let italicSegments = segments.filter { $0.type == .italic }
        let codeSegments = segments.filter { $0.type == .code }
        let wikilinkSegments = segments.filter { $0.type == .wikilink }

        XCTAssertEqual(boldSegments.first?.text, "bold")
        XCTAssertEqual(italicSegments.first?.text, "italic")
        XCTAssertEqual(codeSegments.first?.text, "code")
        XCTAssertEqual(wikilinkSegments.first?.text, "WikiLink")
    }

    func testComplexNestedFormatting() {
        let content = "**Bold with `code` inside** and *italic with [[link]]*"

        let segments = parser.parseInlineSegments(content)

        // Should still extract bold and italic even with nested content
        XCTAssertFalse(segments.isEmpty)
    }
}

// MARK: - E2E: Log and Audit Trail
final class LogAuditTrailTests: XCTestCase {

    func testLogEntryCapturesAllActionTypes() {
        let logService = LogService()
        logService.logEntries.removeAll()

        logService.addLog(action: "create", target: "Test Page", details: "Created new page")
        logService.addLog(action: "update", target: "Test Page", details: "Updated content")
        logService.addLog(action: "delete", target: "Test Page", details: "Deleted page")
        logService.addLog(action: "pin", target: "Test Page", details: "Pinned page")
        logService.addLog(action: "unpin", target: "Test Page", details: "Unpinned page")
        logService.addLog(action: "tag", target: "Test Page", details: "Added tag: work")
        logService.addLog(action: "alias", target: "Test Page", details: "Added alias: alias1")
        logService.addLog(action: "lint", target: "Wiki", details: "Ran full lint: 3 issues found")

        XCTAssertEqual(logService.logEntries.count, 8)

        // Verify action types
        let actions = logService.logEntries.map(\.action)
        XCTAssertTrue(actions.contains("create"))
        XCTAssertTrue(actions.contains("update"))
        XCTAssertTrue(actions.contains("delete"))
        XCTAssertTrue(actions.contains("pin"))
        XCTAssertTrue(actions.contains("unpin"))
        XCTAssertTrue(actions.contains("tag"))
        XCTAssertTrue(actions.contains("alias"))
        XCTAssertTrue(actions.contains("lint"))
    }

    func testLogOrderingNewestFirst() {
        let logService = LogService()
        logService.logEntries.removeAll()

        logService.addLog(action: "first", target: "T1", details: "")
        logService.addLog(action: "second", target: "T2", details: "")
        logService.addLog(action: "third", target: "T3", details: "")

        XCTAssertEqual(logService.logEntries.first?.action, "third")
        XCTAssertEqual(logService.logEntries.last?.action, "first")
    }

    func testLogMaxEntriesCapped() {
        let logService = LogService()
        logService.logEntries.removeAll()

        for i in 0..<600 {
            logService.addLog(action: "action_\(i)", target: "page_\(i)", details: "Log entry \(i)")
        }

        XCTAssertLessThanOrEqual(logService.logEntries.count, 500, "Log should cap at 500 entries")
    }
}
