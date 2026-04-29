import XCTest
@testable import KnowledgeBase

// MARK: - Models Tests
final class ModelsTests: XCTestCase {
    
    // MARK: - WikiPage Tests
    func testWikiPageCreation() {
        let page = WikiPage(title: "Test Page", type: .entity, content: "Hello World")
        XCTAssertEqual(page.title, "Test Page")
        XCTAssertEqual(page.type, .entity)
        XCTAssertEqual(page.content, "Hello World")
        XCTAssertEqual(page.status, .active)
        XCTAssertEqual(page.confidence, .medium)
        XCTAssertTrue(page.aliases.isEmpty)
        XCTAssertTrue(page.tags.isEmpty)
        XCTAssertFalse(page.isPinned)
    }
    
    func testWikiPageStubStatus() {
        let shortPage = WikiPage(title: "Short", content: "Hi")
        XCTAssertTrue(shortPage.isStub)
        
        let longPage = WikiPage(title: "Long", content: String(repeating: "Hello ", count: 30))
        XCTAssertFalse(longPage.isStub)
    }
    
    func testOutgoingLinks() {
        let page = WikiPage(
            title: "Test",
            content: "This links to [[Page A]] and [[Page B]] and [[Page A]] again."
        )
        let links = page.outgoingLinks
        XCTAssertEqual(links.count, 3) // includes duplicate
        XCTAssertEqual(links[0], "Page A")
        XCTAssertEqual(links[1], "Page B")
        XCTAssertEqual(links[2], "Page A")
    }
    
    func testOutgoingLinksNoMatch() {
        let page = WikiPage(title: "Test", content: "No links here.")
        XCTAssertTrue(page.outgoingLinks.isEmpty)
    }
    
    // MARK: - CJK Word Count
    func testEnglishWordCount() {
        let page = WikiPage(title: "Test", content: "Hello World This Is English")
        XCTAssertEqual(page.wordCount, 5)
    }
    
    func testChineseWordCount() {
        let page = WikiPage(title: "Test", content: "这是一个测试")
        XCTAssertEqual(page.wordCount, 6) // 6 CJK characters
    }
    
    func testMixedWordCount() {
        let page = WikiPage(title: "Test", content: "Hello世界Test")
        XCTAssertEqual(page.wordCount, 4) // Hello + 世 + 界 + Test
    }
    
    func testEmptyContentWordCount() {
        let page = WikiPage(title: "Test", content: "")
        XCTAssertEqual(page.wordCount, 0)
    }
    
    // MARK: - PageType Tests
    func testPageTypeDisplayNames() {
        XCTAssertFalse(PageType.entity.displayName.isEmpty)
        XCTAssertFalse(PageType.concept.displayName.isEmpty)
        XCTAssertFalse(PageType.source.displayName.isEmpty)
        XCTAssertFalse(PageType.comparison.displayName.isEmpty)
        XCTAssertFalse(PageType.map.displayName.isEmpty)
        XCTAssertFalse(PageType.raw.displayName.isEmpty)
    }
    
    func testPageTypeIcons() {
        for type in PageType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "PageType.\(type.rawValue) should have an icon")
        }
    }
    
    // MARK: - PageStatus Tests
    func testPageStatusColors() {
        XCTAssertEqual(PageStatus.active.color, .green)
        XCTAssertEqual(PageStatus.stub.color, .yellow)
        XCTAssertEqual(PageStatus.needsUpdate.color, .orange)
        XCTAssertEqual(PageStatus.deprecated.color, .red)
    }
    
    // MARK: - Confidence Tests
    func testConfidenceColors() {
        XCTAssertEqual(Confidence.high.color, .green)
        XCTAssertEqual(Confidence.medium.color, .yellow)
        XCTAssertEqual(Confidence.low.color, .red)
    }
    
    // MARK: - Character Extension
    func testCJKCharacterDetection() {
        XCTAssertTrue(Character("中").isCJKCharacter)
        XCTAssertTrue(Character("日").isCJKCharacter)
        XCTAssertTrue(Character("한").isCJKCharacter)
        XCTAssertFalse(Character("A").isCJKCharacter)
        XCTAssertFalse(Character("1").isCJKCharacter)
        XCTAssertFalse(Character(" ").isCJKCharacter)
    }
}

// MARK: - UndoService Tests
final class UndoServiceTests: XCTestCase {
    
    var undoService: UndoService!
    
    override func setUp() {
        super.setUp()
        undoService = UndoService()
    }
    
    override func tearDown() {
        undoService = nil
        super.tearDown()
    }
    
    func testInitialCanUndoRedo() {
        XCTAssertFalse(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    func testPushSnapshotEnablesUndo() {
        let pages = [WikiPage(title: "Test")]
        undoService.pushSnapshot(pages)
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    func testUndoRestoresPrevious() {
        let oldPages = [WikiPage(title: "Old")]
        let newPages = [WikiPage(title: "New")]
        
        undoService.pushSnapshot(oldPages)
        let result = undoService.undo(currentPages: newPages)
        
        XCTAssertEqual(result?.first?.title, "Old")
        XCTAssertFalse(undoService.canUndo)
        XCTAssertTrue(undoService.canRedo)
    }
    
    func testRedoRestoresNext() {
        let oldPages = [WikiPage(title: "Old")]
        let newPages = [WikiPage(title: "New")]
        
        undoService.pushSnapshot(oldPages)
        _ = undoService.undo(currentPages: newPages)
        let result = undoService.redo(currentPages: oldPages)
        
        XCTAssertEqual(result?.first?.title, "New")
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    func testNewActionClearsRedoStack() {
        let pages1 = [WikiPage(title: "V1")]
        let pages2 = [WikiPage(title: "V2")]
        let pages3 = [WikiPage(title: "V3")]
        
        undoService.pushSnapshot(pages1)
        _ = undoService.undo(currentPages: pages2)
        XCTAssertTrue(undoService.canRedo)
        
        // New action should clear redo
        undoService.pushSnapshot(pages3)
        XCTAssertFalse(undoService.canRedo)
    }
    
    func testMaxStackSize() {
        for i in 0..<60 {
            undoService.pushSnapshot([WikiPage(title: "Page \(i)")])
        }
        // Should be capped at 50
        // We can't directly check stack size, but undo should work
        XCTAssertTrue(undoService.canUndo)
    }
    
    func testClear() {
        undoService.pushSnapshot([WikiPage(title: "Test")])
        undoService.clear()
        XCTAssertFalse(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
}

// MARK: - LinkService Tests
final class LinkServiceTests: XCTestCase {
    
    var linkService: LinkService!
    var samplePages: [WikiPage]!
    
    override func setUp() {
        super.setUp()
        linkService = LinkService()
        
        samplePages = [
            WikiPage(title: "Alpha", type: .entity, content: "Links to [[Beta]] and [[Gamma]]"),
            WikiPage(title: "Beta", type: .concept, content: "Links to [[Alpha]]"),
            WikiPage(title: "Gamma", type: .source, content: "No outgoing links"),
            WikiPage(title: "Delta", type: .concept, content: "Links to [[NonExistent]]", tags: ["test", "sample"])
        ]
    }
    
    override func tearDown() {
        linkService = nil
        samplePages = nil
        super.tearDown()
    }
    
    func testPageByTitle() {
        let found = linkService.pageByTitle("Alpha", in: samplePages)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "Alpha")
    }
    
    func testPageByTitleCaseInsensitive() {
        let found = linkService.pageByTitle("alpha", in: samplePages)
        XCTAssertNotNil(found)
    }
    
    func testPageByTitleNotFound() {
        let found = linkService.pageByTitle("NonExistent", in: samplePages)
        XCTAssertNil(found)
    }
    
    func testPageByID() {
        let targetID = samplePages[0].id
        let found = linkService.pageByID(targetID, in: samplePages)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, targetID)
    }
    
    func testBacklinks() {
        let alphaID = samplePages[0].id
        let backlinks = linkService.backlinks(for: alphaID, in: samplePages)
        // Beta links to Alpha
        XCTAssertTrue(backlinks.contains { $0.title == "Beta" })
    }
    
    func testSearchByTitle() {
        let results = linkService.search(query: "Alpha", in: samplePages)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.title == "Alpha" })
    }
    
    func testSearchByContent() {
        let results = linkService.search(query: "outgoing links", in: samplePages)
        XCTAssertFalse(results.isEmpty)
    }
    
    func testAllTags() {
        let tags = linkService.allTags(in: samplePages)
        XCTAssertFalse(tags.isEmpty)
        XCTAssertTrue(tags.contains { $0.tag == "test" })
    }
}

// MARK: - LintService Tests
final class LintServiceTests: XCTestCase {
    
    var lintService: LintService!
    var linkService: LinkService!
    
    override func setUp() {
        super.setUp()
        lintService = LintService()
        linkService = LinkService()
    }
    
    override func tearDown() {
        lintService = nil
        linkService = nil
        super.tearDown()
    }
    
    func testDetectBrokenLinks() {
        let pages = [
            WikiPage(title: "A", content: "Links to [[NonExistent]]")
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertTrue(issues.contains { $0.message.contains("NonExistent") || $0.message.contains("broken") || $0.message.contains("Broken") })
    }
    
    func testDetectStubContent() {
        let pages = [
            WikiPage(title: "Short", content: "Hi")
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertTrue(issues.contains { $0.message.contains("Short") })
    }
    
    func testNoIssuesForHealthyWiki() {
        let pageA = WikiPage(title: "Alpha", content: String(repeating: "Good content ", count: 20))
        let pageB = WikiPage(title: "Beta", content: "Links to [[Alpha]] " + String(repeating: "content ", count: 15))
        let pages = [pageA, pageB]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        // Should have minimal issues (no broken links, no stubs)
        XCTAssertFalse(issues.contains { $0.message.contains("broken") || $0.message.contains("Broken") })
    }
}
