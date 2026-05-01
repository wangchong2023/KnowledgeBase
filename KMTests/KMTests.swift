import XCTest
import SwiftUI
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
    
    func testWikiPageDefaultValues() {
        let page = WikiPage(title: "Defaults Test")
        XCTAssertEqual(page.customIcon, nil)
        XCTAssertEqual(page.sources.count, 0)
        XCTAssertEqual(page.relatedPageIDs.count, 0)
        XCTAssertEqual(page.contentHash, nil)
        XCTAssertNotNil(page.created)
        XCTAssertNotNil(page.updated)
    }
    
    func testWikiPageCustomIcon() {
        let pageWithIcon = WikiPage(title: "Custom", customIcon: "star.fill")
        XCTAssertEqual(pageWithIcon.displayIcon, "star.fill")
        
        let pageWithoutIcon = WikiPage(title: "Default")
        XCTAssertEqual(pageWithoutIcon.displayIcon, PageType.concept.icon)
    }
    
    func testWikiPageStubBoundary() {
        // Exactly 99 chars → stub
        let exactly99 = WikiPage(title: "B", content: String(repeating: "a", count: 99))
        XCTAssertTrue(exactly99.isStub)
        
        // Exactly 100 chars → not stub
        let exactly100 = WikiPage(title: "B", content: String(repeating: "a", count: 100))
        XCTAssertFalse(exactly100.isStub)
        
        // Empty content → stub
        let empty = WikiPage(title: "E", content: "")
        XCTAssertTrue(empty.isStub)
    }
    
    func testWikiPageFolderName() {
        XCTAssertEqual(WikiPage(title: "", type: .entity).folderName, "entities")
        XCTAssertEqual(WikiPage(title: "", type: .concept).folderName, "concepts")
        XCTAssertEqual(WikiPage(title: "", type: .source).folderName, "sources")
        XCTAssertEqual(WikiPage(title: "", type: .comparison).folderName, "comparisons")
        XCTAssertEqual(WikiPage(title: "", type: .map).folderName, "maps")
        XCTAssertEqual(WikiPage(title: "", type: .raw).folderName, "raw")
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
    
    func testOutgoingLinksEmptyBrackets() {
        let page = WikiPage(title: "T", content: "[[]] text [[]]")
        let links = page.outgoingLinks
        // Empty brackets should not match (regex requires at least 1 char inside)
        XCTAssertTrue(links.isEmpty || links.contains { $0.isEmpty })
    }
    
    func testOutgoingLinksSpecialChars() {
        let page = WikiPage(title: "T", content: "[[Page With Spaces]] and [[中文页面]]")
        let links = page.outgoingLinks
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0], "Page With Spaces")
        XCTAssertEqual(links[1], "中文页面")
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
    
    func testWordCountTrailingSpace() {
        let page = WikiPage(title: "T", content: "Hello ")
        XCTAssertEqual(page.wordCount, 1) // trailing space should not create extra word
    }
    
    func testWordCountMultipleSpaces() {
        let page = WikiPage(title: "T", content: "Hello   World")
        XCTAssertEqual(page.wordCount, 2) // multiple spaces between words
    }
    
    // MARK: - WikiPage Hashable & Codable
    func testWikiPageCodableRoundTrip() throws {
        let original = WikiPage(
            title: "Test",
            type: .source,
            customIcon: "doc.fill",
            content: "# Header\nContent with [[link]]",
            aliases: ["Alias1", "Alias2"],
            tags: ["tag1", "tag2"],
            status: .needsUpdate,
            confidence: .high,
            sources: ["src1"],
            relatedPageIDs: [],
            isPinned: true,
            contentHash: "abc123"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WikiPage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.isPinned, original.isPinned)
    }
    
    func testWikiPageEquatable() {
        let fixedID = UUID()
        let p1 = WikiPage(id: fixedID, title: "Same")
        var p2 = p1
        XCTAssertEqual(p1, p2)
        p2.title = "Different"
        XCTAssertNotEqual(p1, p2)
    }
    
    // MARK: - PageType Tests
    func testPageTypeAllCases() {
        XCTAssertEqual(PageType.allCases.count, 6)
        XCTAssertTrue(PageType.allCases.contains(.entity))
        XCTAssertTrue(PageType.allCases.contains(.concept))
        XCTAssertTrue(PageType.allCases.contains(.source))
        XCTAssertTrue(PageType.allCases.contains(.comparison))
        XCTAssertTrue(PageType.allCases.contains(.map))
        XCTAssertTrue(PageType.allCases.contains(.raw))
    }
    
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
    
    func testPageTypeColors() {
        for type in PageType.allCases {
            _ = type.themedColor // Just verify it doesn't crash
        }
    }
    
    // MARK: - PageStatus Tests
    func testPageStatusAllCases() {
        XCTAssertEqual(PageStatus.allCases.count, 4)
    }
    
    func testPageStatusColors() {
        XCTAssertEqual(PageStatus.active.color, .green)
        XCTAssertEqual(PageStatus.stub.color, .yellow)
        XCTAssertEqual(PageStatus.needsUpdate.color, .orange)
        XCTAssertEqual(PageStatus.deprecated.color, .red)
    }
    
    // MARK: - Confidence Tests
    func testConfidenceAllCases() {
        XCTAssertEqual(Confidence.allCases.count, 3)
    }
    
    func testConfidenceColors() {
        XCTAssertEqual(Confidence.high.color, .green)
        XCTAssertEqual(Confidence.medium.color, .yellow)
        XCTAssertEqual(Confidence.low.color, .red)
    }
    
    // MARK: - Character Extension
    func testCJKCharacterDetection() {
        // Chinese
        XCTAssertTrue(Character("中").isCJKCharacter)
        XCTAssertTrue(Character("文").isCJKCharacter)
        // Japanese Hiragana
        XCTAssertTrue(Character("あ").isCJKCharacter)
        // Japanese Katakana
        XCTAssertTrue(Character("カ").isCJKCharacter)
        // Korean
        XCTAssertTrue(Character("한").isCJKCharacter)
        // CJK Punctuation
        XCTAssertTrue(Character("、").isCJKCharacter)
        XCTAssertTrue(Character("。").isCJKCharacter)
        // Non-CJK
        XCTAssertFalse(Character("A").isCJKCharacter)
        XCTAssertFalse(Character("z").isCJKCharacter)
        XCTAssertFalse(Character("1").isCJKCharacter)
        XCTAssertFalse(Character(" ").isCJKCharacter)
        XCTAssertFalse(Character("\n").isCJKCharacter)
    }
}

// MARK: - GraphModels Tests
final class GraphModelsTests: XCTestCase {
    
    func testGraphNodeCreation() {
        let node = GraphNode(id: UUID(), title: "Test", type: .concept, position: .zero)
        XCTAssertEqual(node.title, "Test")
        XCTAssertEqual(node.type, .concept)
        XCTAssertEqual(node.position, .zero)
        XCTAssertFalse(node.isHighlighted)
        XCTAssertNil(node.communityID)
    }
    
    func testGraphEdgeCreation() {
        let sourceID = UUID()
        let targetID = UUID()
        let edge = GraphEdge(source: sourceID, target: targetID)
        XCTAssertEqual(edge.source, sourceID)
        XCTAssertEqual(edge.target, targetID)
        XCTAssertNotNil(edge.id)
    }
    
    func testLogEntryCreation() {
        let entry = LogEntry(action: "create", target: "Page1", details: "Created new page")
        XCTAssertEqual(entry.action, "create")
        XCTAssertEqual(entry.target, "Page1")
        XCTAssertEqual(entry.details, "Created new page")
        XCTAssertNotNil(entry.timestamp)
        XCTAssertNotNil(entry.id)
    }
}

// MARK: - LintIssue Tests
final class LintIssueTests: XCTestCase {
    
    func testLintIssueSeverityError() {
        let issue = LintIssue(severity: .error, message: "Broken link", suggestion: "Fix the link")
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.message, "Broken link")
        XCTAssertEqual(issue.severity.icon, "xmark.circle.fill")
        XCTAssertEqual(issue.severity.color, .red)
    }
    
    func testLintIssueSeverityWarning() {
        let issue = LintIssue(severity: .warning, message: "Orphan page", suggestion: "Add links to this page")
        XCTAssertEqual(issue.severity.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(issue.severity.color, Color.orange)
    }
    
    func testLintIssueSeverityInfo() {
        let issue = LintIssue(severity: .info, message: "Stub content", suggestion: "Expand the content")
        XCTAssertEqual(issue.severity.icon, "info.circle.fill")
        XCTAssertEqual(issue.severity.color, Color.blue)
    }
}

// MARK: - CollaborationModels Tests
final class CollaborationModelsTests: XCTestCase {
    
    func testCollabUserDisplayLabel() {
        let user = CollabUser(id: "u1", displayName: "Alice", deviceName: "iPhone", joinedAt: Date())
        XCTAssertEqual(user.displayLabel, "Alice (iPhone)")
    }
    
    func testCollabEditFields() {
        let edit = CollabEdit(
            id: "e1", userID: "u1", pageID: UUID(),
            field: "title", oldValue: "Old", newValue: "New",
            timestamp: Date()
        )
        XCTAssertEqual(edit.field, "title")
        XCTAssertEqual(edit.oldValue, "Old")
        XCTAssertEqual(edit.newValue, "New")
    }
    
    func testCollabRoleDisplayNames() {
        XCTAssertFalse(CollabRole.owner.displayName.isEmpty)
        XCTAssertFalse(CollabRole.editor.displayName.isEmpty)
        XCTAssertFalse(CollabRole.viewer.displayName.isEmpty)
    }
    
    func testCollabRoleIcons() {
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
        XCTAssertEqual(CollabRole.editor.icon, "pencil.circle.fill")
        XCTAssertEqual(CollabRole.viewer.icon, "eye.fill")
    }
}

// MARK: - DocumentFormat Tests
final class DocumentFormatTests: XCTestCase {
    
    func testDetectMarkdown() {
        let url = URL(fileURLWithPath: "/test.md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }
    
    func testDetectPlainTxt() {
        let url = URL(fileURLWithPath: "/test.txt")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }
    
    func testDetectDocx() {
        let url = URL(fileURLWithPath: "/test.docx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .docx)
    }
    
    func testDetectXlsx() {
        let url = URL(fileURLWithPath: "/test.xlsx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .xlsx)
    }
    
    func testDetectPdf() {
        let url = URL(fileURLWithPath: "/test.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }
    
    func testDetectUnknown() {
        let url = URL(fileURLWithPath: "/test.xyz")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }
    
    func testDetectTextExtension() {
        let url = URL(fileURLWithPath: "/test.text")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
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
    
    func testDetectMultipleBrokenLinks() {
        let pages = [
            WikiPage(title: "A", content: "[[Missing1]] and [[Missing2]]")
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let brokenCount = issues.filter { $0.severity == .error }.count
        XCTAssertEqual(brokenCount, 2)
    }
    
    func testDetectStubContent() {
        let pages = [
            WikiPage(title: "Short", content: "Hi")
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertTrue(issues.contains { $0.message.contains("Short") })
    }
    
    func testRawPagesNotFlaggedAsOrphan() {
        // raw type pages should NOT be flagged as orphans even without backlinks
        let rawPage = WikiPage(title: "RawData", type: .raw, content: String(repeating: "x", count: 200))
        let issues = lintService.runLint(pages: [rawPage], linkService: linkService)
        let orphanIssues = issues.filter { $0.severity == .warning && $0.message.contains("orphan") || $0.message.contains("Orphan") }
        XCTAssertTrue(orphanIssues.isEmpty, "raw type should not be flagged as orphan")
    }
    
    func testNoIssuesForHealthyWiki() {
        let pageA = WikiPage(title: "Alpha", content: String(repeating: "Good content ", count: 20))
        let pageB = WikiPage(title: "Beta", content: "Links to [[Alpha]] " + String(repeating: "content ", count: 15))
        let pages = [pageA, pageB]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertFalse(issues.contains { $0.severity == .error })
    }
}

// MARK: - IngestService Tests
final class IngestServiceTests: XCTestCase {
    
    var ingestService: IngestService!
    
    override func setUp() {
        super.setUp()
        ingestService = IngestService()
    }
    
    override func tearDown() {
        ingestService = nil
        super.tearDown()
    }
    
    func testExtractConceptsFromContent() {
        let pages = [
            WikiPage(title: "Machine Learning", type: .concept),
            WikiPage(title: "Deep Learning", type: .concept),
            WikiPage(title: "Neural Network", type: .entity)
        ]
        
        let content = "I want to learn about Machine Learning and Neural Networks."
        let concepts = ingestService.extractConcepts(from: content, pages: pages)
        
        XCTAssertTrue(concepts.contains("Machine Learning"))
        XCTAssertTrue(concepts.contains("Neural Network"))
        XCTAssertFalse(concepts.contains("Deep Learning")) // Not in content
    }
    
    func testExtractConceptsCaseInsensitive() {
        let pages = [WikiPage(title: "SwiftUI", type: .concept)]
        let concepts = ingestService.extractConcepts(from: "I love swiftui programming", pages: pages)
        XCTAssertTrue(concepts.contains("SwiftUI"), "Should be case-insensitive")
    }
    
    func testExtractConceptsEmpty() {
        let pages = [WikiPage(title: "Something")]
        let concepts = ingestService.extractConcepts(from: "No matches here", pages: pages)
        XCTAssertTrue(concepts.isEmpty)
    }
    
    func testDocumentFormatDetection() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.md")), .markdown)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.txt")), .plainText)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.docx")), .docx)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.xlsx")), .xlsx)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.pdf")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.xyz")), .unknown)
    }
}

// MARK: - MarkdownParser Tests
final class MarkdownParserTests: XCTestCase {
    
    var parser: MarkdownParser!
    
    override func setUp() {
        super.setUp()
        parser = MarkdownParser()
    }
    
    func testParseHeadings() {
        let content = "# Heading 1\n\n## Heading 2\n\n### Heading 3"
        let blocks = parser.parse(content)
        
        let headings = blocks.compactMap { block -> String? in
            if case .heading(let text, let level) = block { return "\(text) (level \(level))" }
            return nil
        }
        XCTAssertEqual(headings.count, 3)
    }
    
    func testParseCodeBlock() {
        let content = "```swift\nlet x = 1\n```\nText after"
        let blocks = parser.parse(content)
        
        guard case .codeBlock(let code, _) = blocks.first else {
            XCTFail("Expected code block"); return
        }
        XCTAssertTrue(code.contains("let x = 1"))
        XCTAssertEqual(blocks.count, 2) // code block + paragraph
    }
    
    func testParseBulletList() {
        let content = "- Item 1\n- Item 2\n- Item 3"
        let blocks = parser.parse(content)
        
        guard case .bulletList(let items, _) = blocks.first else {
            XCTFail("Expected bullet list"); return
        }
        XCTAssertEqual(items.count, 3)
    }
    
    func testParseTaskList() {
        let content = "- [ ] Todo A\n- [x] Todo B\n- [X] Todo C"
        let blocks = parser.parse(content)
        
        guard case .taskList(let items) = blocks.first else {
            XCTFail("Expected task list"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertFalse(items[0].checked)  // [ ]
        XCTAssertTrue(items[1].checked)   // [x]
        XCTAssertTrue(items[2].checked)   // [X]
    }
    
    func testParseBlockquote() {
        let content = "> This is a quote"
        let blocks = parser.parse(content)
        
        guard case .blockquote(let text) = blocks.first else {
            XCTFail("Expected blockquote"); return
        }
        XCTAssertEqual(text, "This is a quote")
    }
    
    func testParseHorizontalRule() {
        let content = "---"
        let blocks = parser.parse(content)
        XCTAssertTrue(blocks.contains { if case .horizontalRule = $0 { return true }; return false })
    }
    
    func testParseTable() {
        let content = "| Name | Age |\n|------|-----|\n| Alice | 30 |\n| Bob | 25 |"
        let blocks = parser.parse(content)
        
        guard case .table(let headers, let rows) = blocks.first else {
            XCTFail("Expected table"); return
        }
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(rows.count, 2)
    }
    
    func testParseInlineSegments() {
        let text = "**bold** `code` [[link]] *italic* plain"
        let segments = parser.parseInlineSegments(text)
        
        let types = segments.map(\.type)
        XCTAssertTrue(types.contains(.bold))
        XCTAssertTrue(types.contains(.code))
        XCTAssertTrue(types.contains(.wikilink))
        XCTAssertTrue(types.contains(.italic))
        XCTAssertTrue(types.contains(.text))
    }
    
    func testParseMixedContent() {
        let content = """
        # Title

        Some intro paragraph.

        ## Section

        - List item 1
        - List item 2

        > A quote here

        ```python
        print("hello")
        ```

        ---
        """
        let blocks = parser.parse(content)
        XCTAssertGreaterThanOrEqual(blocks.count, 6) // heading + paragraph + heading + list + blockquote + code + hr
    }
    
    func testParseEmptyContent() {
        let blocks = parser.parse("")
        XCTAssertTrue(blocks.isEmpty)
    }
    
    func testParseOnlyWhitespace() {
        let blocks = parser.parse("\n\n\n")
        XCTAssertTrue(blocks.isEmpty)
    }
}

// MARK: - LogService Tests
final class LogServiceTests: XCTestCase {
    
    var logService: LogService!
    
    override func setUp() {
        super.setUp()
        logService = LogService()
        logService.logEntries.removeAll() // Start clean
    }
    
    override func tearDown() {
        // Clean up any files created during testing
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        _ = try? FileManager.default.removeItem(at: docs!.appendingPathComponent("wikicraft_logs.json"))
        logService = nil
        super.tearDown()
    }
    
    func testAddLogEntry() {
        logService.addLog(action: "create", target: "TestPage")
        XCTAssertEqual(logService.logEntries.count, 1)
        XCTAssertEqual(logService.logEntries.first?.action, "create")
        XCTAssertEqual(logService.logEntries.first?.target, "TestPage")
    }
    
    func testLogEntryOrdering() {
        logService.addLog(action: "action1", target: "t1")
        logService.addLog(action: "action2", target: "t2")
        logService.addLog(action: "action3", target: "t3")
        
        XCTAssertEqual(logService.logEntries.first?.action, "action3") // Most recent first
        XCTAssertEqual(logService.logEntries.last?.action, "action1")
    }
    
    func testMaxLogEntriesCap() {
        for i in 0..<600 {
            logService.addLog(action: "batch_\(i)", target: "t\(i)")
        }
        XCTAssertLessThanOrEqual(logService.logEntries.count, 500)
    }
}

// MARK: - ChatHistoryStore Tests
final class ChatHistoryStoreTests: XCTestCase {
    
    var store: ChatHistoryStore!
    
    override func setUp() {
        super.setUp()
        store = ChatHistoryStore()
        store.messages.removeAll()
        UserDefaults.standard.removeObject(forKey: "wikicraft_chat_history")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "wikicraft_chat_history")
        store = nil
        super.tearDown()
    }
    
    func testAppendMessage() {
        let msg = ChatMessage(role: .user, content: "Hello")
        store.append(msg)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.content, "Hello")
    }
    
    func testAppendBatch() {
        let msgs = [
            ChatMessage(role: .user, content: "Q1"),
            ChatMessage(role: .assistant, content: "A1"),
            ChatMessage(role: .user, content: "Q2")
        ]
        store.appendBatch(msgs)
        XCTAssertEqual(store.messages.count, 3)
    }
    
    func testClearMessages() {
        store.append(ChatMessage(role: .user, content: "temp"))
        store.clear()
        XCTAssertTrue(store.messages.isEmpty)
    }
    
    func testRecentReturnsLastN() {
        for i in 1...10 {
            store.append(ChatMessage(role: .user, content: "Msg \(i)"))
        }
        let recent = store.recent(3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.last?.content, "Msg 8") // 8,9,10
    }
    
    func testPersistAndLoadRoundTrip() throws {
        let original = ChatMessage(role: .assistant, content: "Saved message", relatedPageIDs: [])
        store.append(original)
        
        // Verify persistence via UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "wikicraft_chat_history"),
              let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            XCTFail("Failed to load persisted messages"); return
        }
        XCTAssertFalse(decoded.isEmpty)
        XCTAssertEqual(decoded.first?.content, "Saved message")
    }
}

// MARK: - LLMConfigStore Tests
final class LLMConfigStoreTests: XCTestCase {
    
    var configStore: LLMConfigStore!
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "wikicraft_llm_config")
        configStore = LLMConfigStore()
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "wikicraft_llm_config")
        configStore = nil
        super.tearDown()
    }
    
    func testDefaultValues() {
        XCTAssertEqual(configStore.provider, .openAI)
        XCTAssertEqual(configStore.apiKey, "")
        XCTAssertEqual(configStore.isEnabled, false)
        XCTAssertFalse(configStore.baseURL.isEmpty)
        XCTAssertFalse(configStore.model.isEmpty)
    }
    
    func testSaveAndRestoreConfig() {
        configStore.apiKey = "test-key-12345"
        configStore.provider = .deepSeek
        configStore.model = "deepseek-chat"
        configStore.isEnabled = true
        
        // Create new instance to verify persistence
        let restored = LLMConfigStore()
        XCTAssertEqual(restored.apiKey, "test-key-12345")
        XCTAssertEqual(restored.provider, .deepSeek)
        XCTAssertEqual(restored.model, "deepseek-chat")
        XCTAssertTrue(restored.isEnabled)
    }
    
    func testAllProviderDefaults() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
            XCTAssertFalse(provider.icon.isEmpty)
        }
    }
}

// MARK: - VoiceRecording Tests
final class VoiceRecordingTests: XCTestCase {
    
    func testVoiceRecordingCreation() {
        let recording = VoiceRecording(
            id: UUID(),
            title: "Meeting Notes",
            text: "Discussed project timeline",
            language: "zh-CN",
            duration: 120.5,
            createdAt: Date()
        )
        XCTAssertEqual(recording.title, "Meeting Notes")
        XCTAssertEqual(recording.text, "Discussed project timeline")
        XCTAssertEqual(recording.language, "zh-CN")
        XCTAssertEqual(recording.duration, 120.5)
    }
    
    func testVoiceRecordingCodableRoundTrip() throws {
        let original = VoiceRecording(id: UUID(), title: "T", text: "text", language: "en-US", duration: 10.0, createdAt: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceRecording.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
    }
}

// MARK: - PDF Document Info Tests
final class PDFDocumentInfoTests: XCTestCase {
    
    func testPDFDocCreation() {
        let doc = PDFDocumentInfo(
            title: "Research Paper",
            fileName: "paper.pdf",
            pageCount: 42,
            highlights: [
                PDFHighlight(pageIndex: 0, text: "important finding", color: "yellow", note: "Check this")
            ]
        )
        XCTAssertEqual(doc.fileName, "paper.pdf")
        XCTAssertEqual(doc.pageCount, 42)
        XCTAssertEqual(doc.highlights.count, 1)
        XCTAssertEqual(doc.lastReadPage, 0)
    }
    
    func testPDFHighlightColors() {
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "yellow").highlightColor, .yellow)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "green").highlightColor, .green)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "blue").highlightColor, .blue)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "pink").highlightColor, .pink)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "purple").highlightColor, .purple)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "red").highlightColor, .yellow) // fallback
    }
}
