// AppRouterTests.swift
//
// 作者: Wang Chong
// 功能说明: 验证基础入栈逻辑
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
import SwiftUI
@testable import KM

@MainActor
final class AppRouterTests: XCTestCase {
    
    var router: AppRouter!
    
    override func setUp() {
        super.setUp()
        // AppRouter 是单例，测试前清空历史
        router = AppRouter.shared
        router.clearHistory()
    }
    
    override func tearDown() {
        router.clearHistory()
        router = nil
        super.tearDown()
    }
    
    // MARK: - History Tests
    
    /// 验证基础入栈逻辑
    func testAddToHistory_BasicPush() {
        let pageA = WikiPage(title: "Page A")
        router.addToHistory(pageA)
        
        XCTAssertEqual(router.navigationHistory.count, 1)
        XCTAssertEqual(router.navigationHistory.last?.id, pageA.id)
    }
    
    /// 验证连续去重逻辑 (A -> A 应只有 1 个 A)
    func testAddToHistory_Deduplication() {
        let pageA = WikiPage(title: "Page A")
        router.addToHistory(pageA)
        router.addToHistory(pageA) // 再次尝试添加同一个页面
        
        XCTAssertEqual(router.navigationHistory.count, 1, "连续添加同一页面应当去重")
    }
    
    /// 验证非连续重复逻辑 (A -> B -> A 应保留 [A, B, A])
    /// 这是为了确保用户能从 A 跳到 B，再跳回 A 时，面包屑能正确反映路径
    func testAddToHistory_CircularNavigation() {
        let pageA = WikiPage(title: "Page A")
        let pageB = WikiPage(title: "Page B")
        
        router.addToHistory(pageA)
        router.addToHistory(pageB)
        router.addToHistory(pageA)
        
        XCTAssertEqual(router.navigationHistory.count, 3)
        XCTAssertEqual(router.navigationHistory.map { $0.title }, ["Page A", "Page B", "Page A"])
    }
    
    /// 验证历史长度限制 (最大 5 个)
    func testAddToHistory_LimitLength() {
        let pages = (1...6).map { WikiPage(title: "Page \($0)") }
        
        for page in pages {
            router.addToHistory(page)
        }
        
        XCTAssertEqual(router.navigationHistory.count, 5, "历史长度不应超过 5 个")
        XCTAssertEqual(router.navigationHistory.first?.title, "Page 2", "最旧的 Page 1 应当被移除")
        XCTAssertEqual(router.navigationHistory.last?.title, "Page 6", "最新的 Page 6 应当在末尾")
    }
    
    /// 验证清空历史功能
    func testClearHistory() {
        let pageA = WikiPage(title: "Page A")
        router.addToHistory(pageA)
        XCTAssertFalse(router.navigationHistory.isEmpty)
        
        router.clearHistory()
        XCTAssertTrue(router.navigationHistory.isEmpty)
    }
}
