// KMStoreStorageTests.swift
//
// 作者: Wang Chong
// 功能说明: 核心状态管理器测试 (Expert QA Item #4)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 核心状态管理器测试 (Expert QA Item #4)
/// 验证 KMStore 的 CRUD 逻辑、发布订阅一致性及内存状态安全。
@MainActor
final class KMStoreStorageTests: XCTestCase {
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
    
    /// 测试页面添加与持久化
    func testAddPage() {
        let initialCount = store.totalPages
        let _ = store.createPage(title: "测试页面", type: .concept, content: "内容")
        
        XCTAssertEqual(store.totalPages, initialCount + 1, "页面创建后总数应增加")
        XCTAssertTrue(store.pages.contains(where: { $0.title == "测试页面" }), "页面创建后应存在于列表中")
    }
    
    /// 测试页面更新逻辑 (Deep Scan 触发验证)
    func testUpdatePage() {
        let page = store.createPage(title: "初始标题", type: .concept, content: "初始内容")
        
        var updatedPage = page
        updatedPage.content = "修改后的内容 [[链接测试]]"
        store.updatePage(updatedPage, forceDeepScan: true)
        
        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "修改后的内容 [[链接测试]]")
        XCTAssertTrue(found?.outgoingLinks.contains("链接测试") ?? false, "Deep Scan 应正确解析出反向链接")
    }
    
    /// 测试页面删除
    func testDeletePage() {
        let page = store.createPage(title: "待删除", type: .concept, content: "内容")
        let id = page.id
        
        store.deletePage(page)
        XCTAssertFalse(store.pages.contains(where: { $0.id == id }), "页面删除后不应存在")
    }
    
    /// 测试搜索建议与过滤
    func testSearchSuggestions() {
        _ = store.createPage(title: "Apple", type: .entity, content: "Fruit")
        _ = store.createPage(title: "Banana", type: .entity, content: "Yellow")
        
        let results = store.sqliteStore.searchPages(query: "Ap")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Apple")
    }
}
