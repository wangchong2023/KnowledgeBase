import XCTest
@testable import KM

@MainActor
final class LinkServiceTests: XCTestCase {
    var sut: LinkService!
    var mockPages: [WikiPage]!

    override func setUp() {
        super.setUp()
        sut = LinkService()

        // 构造 Mock 数据
        let page1 = WikiPage(title: "Swift", content: "iOS Development language.")
        var page2 = WikiPage(title: "Architecture", content: "Clean Architecture in [[Swift]].")
        page2.aliases = ["Arch"]

        var page3 = WikiPage(title: "Design", content: "UI Design for [[Arch]].")
        page3.tags = ["UI", "UX"]

        mockPages = [page1, page2, page3]
    }

    override func tearDown() {
        sut = nil
        mockPages = nil
        super.tearDown()
    }

    // MARK: - Test pageByTitle
    func testPageByTitle_ExactMatch() async {
        let result = await sut.pageByTitle("Swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }

    func testPageByTitle_CaseInsensitive() async {
        let result = await sut.pageByTitle("swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }

    func testPageByTitle_AliasMatch() async {
        let result = await sut.pageByTitle("Arch", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Architecture")
    }

    // MARK: - Test Backlinks
    func testBacklinks_DirectLink() async {
        guard let swiftPage = await sut.pageByTitle("Swift", in: mockPages) else {
            XCTFail("Swift page should exist")
            return
        }

        let results = await sut.backlinks(for: swiftPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Architecture")
    }

    func testBacklinks_AliasLink() async {
        guard let archPage = await sut.pageByTitle("Architecture", in: mockPages) else {
            XCTFail("Architecture page should exist")
            return
        }

        let results = await sut.backlinks(for: archPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }

    // MARK: - Test Search
    func testSearch_ByTag() async {
        let results = await sut.search(query: "UI", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }

    func testSearch_ByContent() async {
        let results = await sut.search(query: "Development", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift")
    }
}
