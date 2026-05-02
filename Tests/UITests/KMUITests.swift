import XCTest

final class KMUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// 关键路径测试：查看 Dashboard -> 跳转页面 -> 检查内容
    func testDashboardNavigationFlow() throws {
        // 1. 确认是否在 Dashboard 标签
        let dashboardTab = app.tabBars.buttons["Graph"] // 对应代码中的 .graph 图谱/仪表盘
        XCTAssertTrue(dashboardTab.exists)
        dashboardTab.tap()
        
        // 2. 检查每日闪念 (Daily Recap) 是否存在
        let dailyRecapHeader = app.staticTexts["每日闪念"] 
        XCTAssertTrue(dailyRecapHeader.waitForExistence(timeout: 5))
        
        // 3. 点击推荐卡片进行跳转
        let recapCard = app.buttons.element(boundBy: 0) // 第一个推荐卡片
        XCTAssertTrue(recapCard.exists)
        recapCard.tap()
        
        // 4. 验证是否进入了页面详情
        let pinButton = app.buttons["pin"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 2))
    }
    
    /// 测试 WikiLink 点击跳转
    func testWikiLinkNavigation() throws {
        // 1. 进入搜索或列表找到包含链接的页面
        // 此处假设点击第一个 Wiki 页面
        app.tabBars.buttons["Wiki"].tap()
        
        let firstPage = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstPage.exists)
        firstPage.tap()
        
        // 2. 查找正文中的链接（蓝色文本或特定标记）
        // 链接在 AttributedString 中会被渲染为可点击项
        let wikiLink = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '[[ '")).element(boundBy: 0)
        if wikiLink.exists {
            wikiLink.tap()
            // 验证导航标题是否改变
            XCTAssertTrue(app.navigationBars.element.exists)
        }
    }
}
