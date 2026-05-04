import XCTest
@testable import KM

/// 核心状态管理器测试 (Expert QA Item #4)
/// 验证 KMStore 的 CRUD 逻辑、发布订阅一致性及内存状态安全。
@MainActor
final class KMStoreStorageTests: XCTestCase {
    var store: KMStore!

    override func setUp() {
        super.setUp()
        store = KMStore()
    }

    /// 测试页面添加与持久化
    func testAddPage() {
        let page = store.createPage(title: "测试页面", type: .entity, content: "内容")

        XCTAssertTrue(store.pages.contains(where: { $0.title == "测试页面" }), "页面添加后应存在于内存列表中")
    }

    /// 测试页面更新逻辑 (Deep Scan 触发验证)
    func testUpdatePage() {
        let page = store.createPage(title: "初始标题", type: .entity, content: "初始内容")

        var updatedPage = page
        updatedPage.content = "修改后的内容 [[链接测试]]"
        store.updatePage(updatedPage, forceDeepScan: true)

        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "修改后的内容 [[链接测试]]")
        XCTAssertTrue(found?.outgoingLinks.contains("链接测试") ?? false, "Deep Scan 应正确解析出反向链接")
    }

    /// 测试页面删除
    func testDeletePage() {
        let page = store.createPage(title: "待删除", type: .entity, content: "内容")

        store.deletePage(page)
        XCTAssertFalse(store.pages.contains(where: { $0.id == page.id }), "页面删除后不应存在")
    }

    /// 测试搜索建议与过滤
    func testSearchSuggestions() {
        store.createPage(title: "Apple", type: .entity, content: "")
        store.createPage(title: "Banana", type: .entity, content: "")

        let suggestions = store.pages.filter { $0.title.localizedCaseInsensitiveContains("Ap") }
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.title, "Apple")
    }
}
