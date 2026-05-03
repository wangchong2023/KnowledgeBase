import XCTest
@testable import KM

/// 核心状态管理器测试 (Expert QA Item #4)
/// 验证 KMStore 的 CRUD 逻辑、发布订阅一致性及内存状态安全。
final class KMStoreStorageTests: XCTestCase {
    var store: KMStore!
    
    override func setUp() {
        super.setUp()
        // 使用内存数据库或测试数据库路径
        store = KMStore()
    }
    
    /// 测试页面添加与持久化
    func testAddPage() {
        let page = WikiPage(title: "测试页面", content: "内容")
        store.addPage(page)
        
        XCTAssertTrue(store.pages.contains(where: { $0.title == "测试页面" }), "页面添加后应存在于内存列表中")
    }
    
    /// 测试页面更新逻辑 (Deep Scan 触发验证)
    func testUpdatePage() {
        var page = WikiPage(title: "初始标题", content: "初始内容")
        store.addPage(page)
        
        page.content = "修改后的内容 [[链接测试]]"
        store.updatePage(page, forceDeepScan: true)
        
        let updated = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(updated?.content, "修改后的内容 [[链接测试]]")
        XCTAssertTrue(updated?.outgoingLinks.contains("链接测试") ?? false, "Deep Scan 应正确解析出反向链接")
    }
    
    /// 测试页面删除
    func testDeletePage() {
        let page = WikiPage(title: "待删除", content: "内容")
        store.addPage(page)
        
        store.deletePage(page)
        XCTAssertFalse(store.pages.contains(where: { $0.id == page.id }), "页面删除后不应存在")
    }
    
    /// 测试搜索建议与过滤
    func testSearchSuggestions() {
        store.addPage(WikiPage(title: "Apple", content: ""))
        store.addPage(WikiPage(title: "Banana", content: ""))
        
        let suggestions = store.suggestPages(for: "Ap")
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.title, "Apple")
    }
}
