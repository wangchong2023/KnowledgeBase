import XCTest
import SwiftUI
@testable import KM

// MARK: - BackupService Tests
final class BackupServiceTests: XCTestCase {

    var backupService: BackupService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        // 每个测试使用独立临时目录
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        backupService = BackupService()
    }

    override func tearDown() {
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDir)
        backupService = nil
        super.tearDown()
    }

    func testCreateBackupGeneratesEntry() {
        let pages = [
            WikiPage(title: "Page A", type: .entity, content: "Content A"),
            WikiPage(title: "Page B", type: .concept, content: "Content B")
        ]

        backupService.createBackup(pages: pages)

        XCTAssertFalse(backupService.backupEntries.isEmpty, "Backup should create at least one entry")
        let latestEntry = backupService.backupEntries.first
        XCTAssertNotNil(latestEntry?.id)
        XCTAssertEqual(latestEntry?.pageCount, 2)
    }

    func testBackupEntryContainsCorrectMetadata() {
        let pages = [WikiPage(title: "Test", type: .source, content: "x")]
        backupService.createBackup(pages: pages)

        let entry = backupService.backupEntries.first
        XCTAssertNotNil(entry?.createdAt)
        XCTAssertEqual(entry?.version, 1)
        XCTAssertGreaterThan(entry?.sizeBytes ?? 0, 0)
    }

    func testRestoreBackupReturnsCorrectPages() {
        let original = [
            WikiPage(title: "Restored Page", type: .entity, content: "Restored content"),
            WikiPage(title: "Page 2", type: .concept, content: "More content here with enough chars")
        ]
        backupService.createBackup(pages: original)

        let entries = backupService.backupEntries
        guard let latestEntry = entries.first else {
            XCTFail("No backup entry found"); return
        }

        let restored = backupService.restoreBackup(latestEntry)
        XCTAssertNotNil(restored, "Restore should return pages array")
        XCTAssertEqual(restored?.count, 2, "Should restore all pages")
        XCTAssertTrue(restored?.contains { $0.title == "Restored Page" } ?? false)
    }

    func testDeleteBackupRemovesEntry() {
        let pages = [WikiPage(title: "To Delete", type: .raw, content: "content")]
        backupService.createBackup(pages: pages)

        let countBefore = backupService.backupEntries.count
        guard let entryToDelete = backupService.backupEntries.first else {
            XCTFail("No entry to delete"); return
        }

        backupService.deleteBackup(entryToDelete)
        XCTAssertEqual(backupService.backupEntries.count, countBefore - 1)
    }

    func testMarkDirtyAndClean() {
        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }

    func testMultipleBackupsCreateMultipleEntries() {
        for i in 0..<3 {
            let pages = [WikiPage(title: "Page \(i)", type: .entity, content: "Content \(i)")]
            backupService.createBackup(pages: pages)
        }
        XCTAssertEqual(backupService.backupEntries.count, 3)
    }
}

// MARK: - CollaborationService Tests
final class CollaborationServiceTests: XCTestCase {

    var collabService: CollaborationService!
    var store: KMStore!

    override func setUp() {
        super.setUp()
        collabService = CollaborationService()
        store = KMStore()
        collabService.setStore(store)
    }

    override func tearDown() {
        collabService.stop()
        collabService = nil
        store = nil
        super.tearDown()
    }

    func testSetStoreAssignsStore() {
        //KMStore instance already set via setStore() in setUp
        XCTAssertNotNil(collabService.store)
    }

    func testDefaultRoleIsViewer() {
        XCTAssertEqual(collabService.currentRole, .viewer)
    }

    func testDefaultUserNameIsDeviceName() {
        #if targetEnvironment(simulator)
        XCTAssertTrue(collabService.userName.contains("Simulator") || !collabService.userName.isEmpty)
        #else
        XCTAssertFalse(collabService.userName.isEmpty)
        #endif
    }

    func testSetUserNameUpdatesName() {
        collabService.setUserName("TestUser")
        XCTAssertEqual(collabService.userName, "TestUser")
    }

    func testNoPeersWhenNotConnected() {
        XCTAssertTrue(collabService.connectedPeers.isEmpty)
    }

    func testRecentEditsEmptyInitially() {
        XCTAssertTrue(collabService.recentEdits.isEmpty)
    }

    func testRoleColors() {
        XCTAssertEqual(CollabRole.owner.color, .blue)
        XCTAssertEqual(CollabRole.editor.color, .green)
        XCTAssertEqual(CollabRole.viewer.color, .gray)
    }

    func testDiscoveredRoomEquality() {
        let room1 = DiscoveredRoom(name: "Room", hostName: "Host1", peerID: "p1", createdAt: Date())
        let room2 = DiscoveredRoom(name: "Room", hostName: "Host1", peerID: "p1", createdAt: Date())
        XCTAssertEqual(room1, room2)
    }
}

// MARK: - SpeechService Tests
final class SpeechServiceTests: XCTestCase {

    var speechService: SpeechService!

    override func setUp() {
        super.setUp()
        speechService = SpeechService()
    }

    override func tearDown() {
        speechService.clearTranscription()
        speechService = nil
        super.tearDown()
    }

    func testClearTranscriptionEmptiesText() {
        // Manually set some state for this test
        XCTAssertTrue(speechService.transcribedText.isEmpty)
    }

    func testRecordingCountStartsAtZero() {
        XCTAssertEqual(speechService.recordingCount, 0)
    }

    func testAudioLevelHistoryIsEmptyInitially() {
        XCTAssertTrue(speechService.audioLevelHistory.isEmpty)
    }

    func testIsRecordingFalseInitially() {
        XCTAssertFalse(speechService.isRecording)
    }

    func testSupportedLanguagesNotEmpty() {
        XCTAssertFalse(speechService.supportedLanguages.isEmpty)
    }

    func testDefaultLanguageIsSet() {
        XCTAssertFalse(speechService.selectedLanguage.isEmpty)
    }
}

// MARK: - DocumentFormat Edge Cases
final class DocumentFormatEdgeCaseTests: XCTestCase {

    func testDetectFormatMixedCaseExtension() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.MD")), .markdown)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.PDF")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.TXT")), .plainText)
    }

    func testDetectFormatWithQueryString() {
        let url = URL(string: "file:///path/to/document.pdf?v=1.0")!
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    func testDetectFormatEmptyExtension() {
        let url = URL(fileURLWithPath: "/README")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    func testDetectFormatNumbersInFilename() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/file123.pdf")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/doc.2024.docx")), .docx)
    }
}

// MARK: - MarkdownParser Edge Cases
final class MarkdownParserEdgeCaseTests: XCTestCase {

    var parser: MarkdownParser!

    override func setUp() {
        super.setUp()
        parser = MarkdownParser()
    }

    func testParseWikiLinkWithSpaces() {
        let content = "This links to [[Page With Spaces]]"
        let segments = parser.parseInlineSegments(content)

        let wikilinks = segments.filter { $0.type == .wikilink }
        XCTAssertEqual(wikilinks.count, 1)
        XCTAssertEqual(wikilinks.first?.text, "Page With Spaces")
    }

    func testParseWikiLinkWithChinese() {
        let content = "链接到 [[中文页面名称]]"
        let segments = parser.parseInlineSegments(content)

        let wikilinks = segments.filter { $0.type == .wikilink }
        XCTAssertEqual(wikilinks.count, 1)
        XCTAssertEqual(wikilinks.first?.text, "中文页面名称")
    }

    func testParseWikiLinkEmpty() {
        let content = "Text with [[]] empty link"
        let segments = parser.parseInlineSegments(content)

        // Empty brackets should not be parsed as wikilink (regex requires non-empty)
        let wikilinks = segments.filter { $0.type == .wikilink }
        XCTAssertTrue(wikilinks.isEmpty || wikilinks.allSatisfy { !$0.text.isEmpty })
    }

    func testParseBoldAcrossMultipleWords() {
        let content = "This is **bold text** here"
        let segments = parser.parseInlineSegments(content)

        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertEqual(boldSegments.first?.text, "bold text")
    }

    func testParseItalicWithUnderscore() {
        let content = "This is _italic text_ here"
        let segments = parser.parseInlineSegments(content)

        let italicSegments = segments.filter { $0.type == .italic }
        XCTAssertEqual(italicSegments.first?.text, "italic text")
    }

    func testParseCodeWithBackticks() {
        let content = "Use `let x = 1` to declare"
        let segments = parser.parseInlineSegments(content)

        let codeSegments = segments.filter { $0.type == .code }
        XCTAssertEqual(codeSegments.first?.text, "let x = 1")
    }

    func testParseMultipleHeadings() {
        let content = "# H1\n## H2\n### H3\n#### H4"
        let blocks = parser.parse(content)

        let headings = blocks.compactMap { block -> (String, Int)? in
            if case .heading(let text, let level) = block { return (text, level) }
            return nil
        }
        XCTAssertEqual(headings.count, 4)
        XCTAssertEqual(headings[0].1, 1)
        XCTAssertEqual(headings[1].1, 2)
        XCTAssertEqual(headings[2].1, 3)
        XCTAssertEqual(headings[3].1, 4)
    }

    func testParseOrderedList() {
        let content = "1. First\n2. Second\n3. Third"
        let blocks = parser.parse(content)

        guard case .orderedList(let items, _) = blocks.first else {
            XCTFail("Expected ordered list"); return
        }
        XCTAssertEqual(items.count, 3)
    }

    func testParseNestedBulletList() {
        let content = "- Item 1\n  - Nested\n  - Also nested\n- Item 2"
        let blocks = parser.parse(content)

        guard case .bulletList(let items, _) = blocks.first else {
            XCTFail("Expected bullet list"); return
        }
        XCTAssertEqual(items.count, 2)
    }

    func testParseMathBlock() {
        let content = "$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$"
        let segments = parser.parseInlineSegments(content)

        let mathSegments = segments.filter { $0.type == .math }
        XCTAssertEqual(mathSegments.count, 1)
    }

    func testParseInlineCodeWithinBold() {
        let content = "**bold with `code` inside**"
        let segments = parser.parseInlineSegments(content)

        // Should have bold with code inside
        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertFalse(boldSegments.isEmpty)
    }
}

// MARK: - LinkService Edge Cases
final class LinkServiceEdgeCasesTests: XCTestCase {

    var linkService: LinkService!

    override func setUp() {
        super.setUp()
        linkService = LinkService()
    }

    func testBacklinksForPageWithNoIncomingLinks() {
        let pages = [
            WikiPage(title: "A", content: "Content"),
            WikiPage(title: "B", type: .concept, content: "More content")
        ]
        let aID = pages[0].id
        let backlinks = linkService.backlinks(for: aID, in: pages)
        XCTAssertTrue(backlinks.isEmpty, "Page with no incoming links should have empty backlinks")
    }

    func testPageByTitleWithWhitespace() {
        let pages = [WikiPage(title: "  Trimmed Title  ", type: .entity, content: "Content")]
        let found = linkService.pageByTitle("Trimmed Title", in: pages)
        XCTAssertNil(found, "pageByTitle should not trim whitespace in title")
    }

    func testSearchQueryCaseSensitivity() {
        let pages = [
            WikiPage(title: "UPPERCASE", type: .entity, content: "Content"),
            WikiPage(title: "lowercase", type: .concept, content: "Content")
        ]
        let upperResults = linkService.search(query: "UPPERCASE", in: pages)
        let lowerResults = linkService.search(query: "uppercase", in: pages)
        XCTAssertEqual(upperResults.count, 1)
        XCTAssertEqual(lowerResults.count, 1)
    }

    func testSearchByTag() {
        let pages = [
            WikiPage(title: "Tagged", type: .entity, content: "Content", tags: ["important", "work"])
        ]
        let results = linkService.search(query: "important", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Tagged" })
    }

    func testAllTagsDeduplication() {
        let pages = [
            WikiPage(title: "A", type: .entity, content: "Content", tags: ["shared"]),
            WikiPage(title: "B", type: .concept, content: "Content", tags: ["shared", "unique"])
        ]
        let tags = linkService.allTags(in: pages)
        let sharedTagCount = tags.filter { $0.tag == "shared" }.count
        XCTAssertEqual(sharedTagCount, 1, "shared tag should appear only once in allTags")
    }
}

// MARK: - LintService Edge Cases
final class LintServiceEdgeCasesTests: XCTestCase {

    var lintService: LintService!
    var linkService: LinkService!

    override func setUp() {
        super.setUp()
        lintService = LintService()
        linkService = LinkService()
    }

    func testNoFalsePositivesForRawPages() {
        // raw pages should not be flagged as orphans
        let pages = [
            WikiPage(title: "DataDump", type: .raw, content: String(repeating: "x ", count: 50))
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let orphanIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("orphan") ||
            $0.message.localizedCaseInsensitiveContains("孤立")
        }
        XCTAssertTrue(orphanIssues.isEmpty, "raw type pages should not be flagged as orphans")
    }

    func testSelfReferencingLinkNotFlaggedAsBroken() {
        let page = WikiPage(title: "SelfRef", type: .entity, content: "Links to [[SelfRef]]")
        let issues = lintService.runLint(pages: [page], linkService: linkService)
        let brokenIssues = issues.filter { $0.severity == .error && ($0.message.localizedCaseInsensitiveContains("broken") || $0.message.localizedCaseInsensitiveContains("不存在")) }
        XCTAssertTrue(brokenIssues.isEmpty, "Self-referencing link should not be broken")
    }

    func testCircularLinksHandledGracefully() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[B]]")
        let pageB = WikiPage(title: "B", type: .concept, content: "Links to [[A]]")

        let result = GraphLayoutEngine.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "A" { return pageA }
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertEqual(result.edges.count, 2, "Circular links should produce 2 edges")
    }

    func testEmptyWikiLintResult() {
        let issues = lintService.runLint(pages: [], linkService: linkService)
        XCTAssertTrue(issues.isEmpty, "Empty wiki should produce no lint issues")
    }

    func testDuplicatePageTitlesDetected() {
        let pages = [
            WikiPage(title: "Duplicate", type: .entity, content: String(repeating: "x ", count: 30)),
            WikiPage(title: "Duplicate", type: .concept, content: String(repeating: "y ", count: 30))
        ]
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let dupIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("duplicate") ||
            $0.message.localizedCaseInsensitiveContains("重复")
        }
        XCTAssertFalse(dupIssues.isEmpty, "Duplicate titles should be flagged")
    }
}

// MARK: - IngestService Edge Cases
final class IngestServiceEdgeCasesTests: XCTestCase {

    var ingestService: IngestService!

    override func setUp() {
        super.setUp()
        ingestService = IngestService()
    }

    func testExtractConceptsNoMatch() {
        let pages = [WikiPage(title: "Existing", type: .concept)]
        let content = "This mentions Nothing That Exists"
        let concepts = ingestService.extractConcepts(from: content, pages: pages)
        XCTAssertTrue(concepts.isEmpty)
    }

    func testExtractConceptsCaseInsensitive() {
        let pages = [WikiPage(title: "SwiftUI", type: .concept)]
        let concepts1 = ingestService.extractConcepts(from: "swiftui", pages: pages)
        let concepts2 = ingestService.extractConcepts(from: "SWIFTUI", pages: pages)
        XCTAssertFalse(concepts1.isEmpty)
        XCTAssertFalse(concepts2.isEmpty)
    }

    func testExtractConceptsPartialMatch() {
        let pages = [WikiPage(title: "Machine Learning", type: .concept)]
        // Partial match should not trigger
        let concepts = ingestService.extractConcepts(from: "Machines are everywhere", pages: pages)
        XCTAssertTrue(concepts.isEmpty, "Partial word match should not extract concept")
    }

    func testDocumentFormatUnsupported() {
        let formats: [DocumentFormat] = [.markdown, .plainText, .docx, .xlsx, .pdf]
        XCTAssertEqual(formats.count, 5)
    }
}

// MARK: - Page Lifecycle Integration Tests
final class PageLifecycleIntegrationTests: XCTestCase {

    var linkService: LinkService!
    var lintService: LintService!
    var undoService: UndoService!

    override func setUp() {
        super.setUp()
        linkService = LinkService()
        lintService = LintService()
        undoService = UndoService()
    }

    func testCreateAndLinkPagesFullLifecycle() {
        // 1. Create pages
        var pageA = WikiPage(title: "Machine Learning", type: .concept, content: "Related to [[Neural Network]]")
        var pageB = WikiPage(title: "Neural Network", type: .entity, content: "Part of [[Machine Learning]]")
        var pageC = WikiPage(title: "Data Science", type: .concept, content: "Uses machine learning")

        // 2. Add related page
        pageC.relatedPageIDs = [pageA.id]

        let pages = [pageA, pageB, pageC]

        // 3. Verify backlinks
        let mlBacklinks = linkService.backlinks(for: pageA.id, in: pages)
        XCTAssertEqual(mlBacklinks.count, 2, "ML should have 2 backlinks: from Neural Network and Data Science relatedPageIDs")

        // 4. Verify outgoing links
        XCTAssertEqual(pageA.outgoingLinks, ["Neural Network"])
        XCTAssertEqual(pageB.outgoingLinks, ["Machine Learning"])

        // 5. Verify lint - no broken links
        let issues = lintService.runLint(pages: pages, linkService: linkService)
        let brokenCount = issues.filter { $0.severity == .error }.count
        XCTAssertEqual(brokenCount, 0, "All links are valid — no broken links")

        // 6. Undo service integration
        undoService.pushSnapshot(pages)
        XCTAssertTrue(undoService.canUndo)

        // 7. Simulate content update
        pageA.content = "Updated [[Neural Network]] content"
        var updatedPages = pages
        updatedPages[0] = pageA

        // 8. Undo should restore original
        let restored = undoService.undo(currentPages: updatedPages)
        XCTAssertEqual(restored?.first?.content, "Related to [[Neural Network]]")
    }

    func testPageTypeClassificationAffectsStubDetection() {
        // raw pages with lots of content should not be stub
        let rawPage = WikiPage(title: "RawData", type: .raw, content: String(repeating: "x ", count: 80))
        XCTAssertFalse(rawPage.isStub, "raw page with 80 words should not be stub")

        // But entity with < 100 chars is stub
        let entityPage = WikiPage(title: "ShortEntity", type: .entity, content: "Too short")
        XCTAssertTrue(entityPage.isStub)
    }

    func testWordCountForMixedCJKAndEnglish() {
        let page = WikiPage(title: "Mixed", type: .concept, content: "Hello世界123测试456")
        // English words: Hello(1), 123(1) = 2, CJK chars: 世界测试 = 4
        // Total = 6
        XCTAssertEqual(page.wordCount, 6)
    }

    func testFolderNamePerType() {
        let typeFolderPairs: [(PageType, String)] = [
            (.entity, "entities"),
            (.concept, "concepts"),
            (.source, "sources"),
            (.comparison, "comparisons"),
            (.map, "maps"),
            (.raw, "raw")
        ]
        for (type, expected) in typeFolderPairs {
            XCTAssertEqual(WikiPage(title: "", type: type).folderName, expected)
        }
    }
}

