import XCTest
@testable import KM

@MainActor
final class KMStoreTests: XCTestCase {
    var store: KMStore!
    
    override func setUp() {
        super.setUp()
        store = KMStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    func testPageCreation() {
        let initialCount = store.totalPages
        let _ = store.createPage(title: "Test Page", type: .concept, content: "Test Content")
        XCTAssertEqual(store.totalPages, initialCount + 1)
    }
    
    func testUndoRedo() {
        let initialCount = store.totalPages
        let page = store.createPage(title: "Undo Test", type: .concept)
        XCTAssertEqual(store.totalPages, initialCount + 1)
        
        store.undo()
        XCTAssertEqual(store.totalPages, initialCount)
        
        store.redo()
        XCTAssertEqual(store.totalPages, initialCount + 1)
    }
    
    func testTagManagement() async {
        let page = store.createPage(title: "Tag Test", type: .concept, tags: ["OldTag"])
        XCTAssertTrue(store.pages.contains { $0.tags.contains("OldTag") })
        
        store.renameTag("OldTag", to: "NewTag")
        XCTAssertTrue(store.pages.contains { $0.tags.contains("NewTag") })
        XCTAssertFalse(store.pages.contains { $0.tags.contains("OldTag") })
        
        store.deleteTag("NewTag")
        XCTAssertFalse(store.pages.contains { $0.tags.contains("NewTag") })
    }
}
