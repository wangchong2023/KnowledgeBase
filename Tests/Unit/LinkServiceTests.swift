import XCTest
@testable import KM

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
    func testPageByTitle_ExactMatch() {
        let result = sut.pageByTitle("Swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }
    
    func testPageByTitle_CaseInsensitive() {
        let result = sut.pageByTitle("swift", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift")
    }
    
    func testPageByTitle_AliasMatch() {
        let result = sut.pageByTitle("Arch", in: mockPages)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Architecture")
    }
    
    // MARK: - Test Backlinks
    func testBacklinks_DirectLink() {
        guard let swiftPage = sut.pageByTitle("Swift", in: mockPages) else {
            XCTFail("Swift page should exist")
            return
        }
        
        let results = sut.backlinks(for: swiftPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Architecture")
    }
    
    func testBacklinks_AliasLink() {
        guard let archPage = sut.pageByTitle("Architecture", in: mockPages) else {
            XCTFail("Architecture page should exist")
            return
        }
        
        let results = sut.backlinks(for: archPage.id, in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }
    
    // MARK: - Test Search
    func testSearch_ByTag() {
        let results = sut.search(query: "UI", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Design")
    }
    
    func testSearch_ByContent() {
        let results = sut.search(query: "Development", in: mockPages)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift")
    }
}
