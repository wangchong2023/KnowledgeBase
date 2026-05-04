// KMStoreTests.swift
//
// 作者: Wang Chong
// 功能说明: KM存储Tests.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

@MainActor
final class KMStoreTests: XCTestCase {
    var store: KMStore!
    
    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        DatabaseManager.shared.reset()
        
        let testDBURL = URL(string: "file::memory:?cache=shared")!
        let sqliteStore = SQLiteStore(dbURL: testDBURL)
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(LogService(), for: LogServiceProtocol.self)
        ServiceContainer.shared.register(LinkService(), for: LinkService.self)
        ServiceContainer.shared.register(LintService(), for: LintService.self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(BackupService(), for: BackupService.self)

        store = KMStore()
    }
    
    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
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
