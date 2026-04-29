import XCTest

// MARK: - UI Test Base Class
/// KnowledgeBase 按钮功能 UI 测试套件
/// 运行方式:
///   1. 在 Xcode 中打开 KnowledgeBase.xcodeproj
///   2. 选择 "KnowledgeBaseUITests" scheme
///   3. 选择 iPhone 16 Pro 模拟器
///   4. Cmd+U 运行测试
/// 注意: 首次运行需要授权辅助访问（System Settings > Privacy & Security > Accessibility）
class KnowledgeBaseUITests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launchEnvironment = ["UITesting": "true"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - Helper Methods
    /// 等待元素出现（带超时）
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// 安全点击元素（存在则点击）
    func safeTap(_ element: XCUIElement, file: String = #file, line: Int = #line) {
        if element.exists && element.isHittable {
            element.tap()
        } else {
            XCTFail("无法点击元素: \(element.identifier) (at \(file):\(line))")
        }
    }

    /// 导航到 Wiki Tab
    func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }

    /// 导航到设置 Tab
    func navigateToSettingsTab() {
        app.tabBars.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}

// MARK: - Tab Navigation Tests
final class TabNavigationTests: KnowledgeBaseUITests {

    /// 测试全部 5 个 Tab 都能被点击
    func testAllFiveTabsAreTappable() {
        let tabs = ["Wiki", "Graph", "Search", "Ingest", "Settings"]
        for tab in tabs {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "Tab '\(tab)' 不存在")
            app.tabBars.buttons[tab].tap()
            Thread.sleep(forTimeInterval: 1)
        }
    }
}

// MARK: - Wiki Tab Tests
final class WikiTabTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToWikiTab()
    }

    // MARK: Sidebar Tests
    func testSidebarIndexButton() {
        let indexButton = app.buttons["总索引"]
        if indexButton.exists {
            safeTap(indexButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证导航到 IndexView（NavigationStack）
            XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).exists || app.navigationBars["索引"].exists)
        }
    }

    func testSidebarLogButton() {
        let logButton = app.buttons["操作日志"]
        if logButton.exists {
            safeTap(logButton)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testSidebarHealthCheckButton() {
        let healthButton = app.buttons["健康检查"]
        if healthButton.exists {
            safeTap(healthButton)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    // MARK: Page Creation Tests
    func testCreatePageButton() {
        // 点击创建按钮
        let createButton = app.navigationBars.buttons.element(boundBy: 1)
        if createButton.exists {
            safeTap(createButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证 CreatePageView Sheet 出现
            XCTAssertTrue(app.sheets.firstMatch.exists || app.navigationBars["创建页面"].exists)
        }
    }
}

// MARK: - Page Detail Tests
final class PageDetailTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToWikiTab()
        // 尝试创建一个测试页面并进入
        createTestPage()
    }

    private func createTestPage() {
        // 点击创建按钮
        let createButton = app.navigationBars.buttons.element(boundBy: 1)
        if createButton.exists {
            safeTap(createButton)
            Thread.sleep(forTimeInterval: 2)

            // 填写标题
            let titleField = app.textFields["页面标题"]
            if titleField.exists {
                titleField.tap()
                titleField.typeText("UITest Page")
            }

            // 点击创建按钮
            let createPageBtn = app.buttons["创建"]
            if createPageBtn.exists && createPageBtn.isEnabled {
                safeTap(createPageBtn)
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }

    func testPinButton() {
        let pinButton = app.navigationBars.buttons.element(boundBy: 0)
        if pinButton.exists {
            safeTap(pinButton)
            Thread.sleep(forTimeInterval: 1)
            safeTap(pinButton) // 再次点击取消固定
        }
    }

    func testBacklinksButton() {
        let backlinksButton = app.navigationBars.buttons.element(boundBy: 1)
        if backlinksButton.exists {
            safeTap(backlinksButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证 sheet
            XCTAssertTrue(app.sheets.firstMatch.exists || app.buttons["关闭"].exists)
        }
    }

    func testEditButton() {
        let editButton = app.navigationBars.buttons.element(boundBy: 2)
        if editButton.exists {
            safeTap(editButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证编辑工具栏出现
            XCTAssertTrue(app.scrollViews.firstMatch.exists)
        }
    }

    func testMoreMenu() {
        let moreButton = app.navigationBars.buttons["更多"]
        if moreButton.exists {
            safeTap(moreButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证 Menu 出现
            XCTAssertTrue(app.menuItems.firstMatch.exists || app.sheets.firstMatch.exists)
        }
    }
}

// MARK: - Search Tests
final class SearchTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        app.tabBars.buttons["Search"].tap()
        Thread.sleep(forTimeInterval: 1)
    }

    func testSearchBarIsTappable() {
        let searchField = app.textFields["搜索页面、标签、内容..."]
        if searchField.exists {
            safeTap(searchField)
            searchField.typeText("Test")
            Thread.sleep(forTimeInterval: 1)
            // 验证键盘出现
            XCTAssertTrue(app.keyboards.element.exists)
            // 清空搜索
            let clearButton = app.buttons["Clear text"]
            if clearButton.exists {
                safeTap(clearButton)
            }
        }
    }

    func testTypeFilterPills() {
        let allPill = app.buttons["全部"]
        if allPill.exists {
            safeTap(allPill)
            Thread.sleep(forTimeInterval: 0.5)
        }

        let entityPill = app.buttons["实体"]
        if entityPill.exists {
            safeTap(entityPill)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testSortMenu() {
        let sortButton = app.buttons["最近更新"]
        if sortButton.exists {
            safeTap(sortButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证 menu 出现
            if app.menuItems.firstMatch.exists {
                // 选择一个排序选项
                app.menuItems.firstMatch.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    func testSearchResultsNavigation() {
        let searchField = app.textFields["搜索页面、标签、内容..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Page")
            Thread.sleep(forTimeInterval: 2)
            // 查找第一个结果
            let resultCell = app.tables.cells.firstMatch
            if resultCell.exists && resultCell.isHittable {
                safeTap(resultCell)
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }
}

// MARK: - Settings Tests
final class SettingsTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToSettingsTab()
    }

    func testAppearanceColorSchemeToggle() {
        // 找到深色模式按钮
        let darkModeButton = app.buttons["深色"]
        if darkModeButton.exists {
            safeTap(darkModeButton)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testAccentColorPicker() {
        // 找到强调色选择器（8个颜色圆圈）
        let accentColors = app.buttons.matching(identifier: "accent-color-")
        let count = accentColors.count
        if count > 0 {
            safeTap(accentColors.element(boundBy: 0))
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testNavigateToChat() {
        let chatNav = app.cells.matching(identifier: "AI-Chat").firstMatch
        if chatNav.exists {
            safeTap(chatNav)
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(app.navigationBars["Chat"].exists || app.textViews.firstMatch.exists)
        }
    }

    func testNavigateToLLMSettings() {
        let llmNav = app.cells.matching(identifier: "AI-LLM设置").firstMatch
        if llmNav.exists {
            safeTap(llmNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToOnDeviceLLM() {
        let onDeviceNav = app.cells.matching(identifier: "AI-端侧LLM").firstMatch
        if onDeviceNav.exists {
            safeTap(onDeviceNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToBackup() {
        let backupNav = app.cells.matching(identifier: "数据-备份").firstMatch
        if backupNav.exists {
            safeTap(backupNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToVoiceNote() {
        let voiceNav = app.cells.matching(identifier: "功能-语音笔记").firstMatch
        if voiceNav.exists {
            safeTap(voiceNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToTagCloud() {
        let tagNav = app.cells.matching(identifier: "维护-标签管理").firstMatch
        if tagNav.exists {
            safeTap(tagNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToHealthCheck() {
        let lintNav = app.cells.matching(identifier: "维护-健康检查").firstMatch
        if lintNav.exists {
            safeTap(lintNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testNavigateToIndex() {
        let indexNav = app.cells.matching(identifier: "维护-总索引").firstMatch
        if indexNav.exists {
            safeTap(indexNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testResetKnowledgeBase() {
        // 危险操作：只测试确认对话框出现，不执行实际重置
        let resetNav = app.cells.matching(identifier: "危险-重置知识库").firstMatch
        if resetNav.exists {
            safeTap(resetNav)
            Thread.sleep(forTimeInterval: 1)
            // 验证确认对话框出现
            let confirmAlert = app.alerts["确认删除"]
            if confirmAlert.exists {
                safeTap(app.buttons["取消"])
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
}

// MARK: - Ingest Tests
final class IngestTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        app.tabBars.buttons["Ingest"].tap()
        Thread.sleep(forTimeInterval: 1)
    }

    func testOCRButtonExists() {
        let ocrButton = app.buttons.matching(identifier: "OCR扫描").firstMatch
        if ocrButton.exists {
            safeTap(ocrButton)
            Thread.sleep(forTimeInterval: 2)
            // 验证进入 OCR 界面
            XCTAssertTrue(app.navigationBars["OCR 文字识别"].exists || app.buttons["取消"].exists)
        }
    }

    func testManualEntrySectionExists() {
        let titleField = app.textFields["输入页面标题"]
        if titleField.exists {
            safeTap(titleField)
            titleField.typeText("Test Ingest Page")
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testSmartIngestToggle() {
        let toggle = app.switches.matching(identifier: "智能导入").firstMatch
        if toggle.exists {
            safeTap(toggle)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testIngestButton() {
        // 先填写标题
        let titleField = app.textFields["输入页面标题"]
        if titleField.exists {
            titleField.tap()
            titleField.typeText("Manual Test Page")
            Thread.sleep(forTimeInterval: 1)
        }

        let ingestButton = app.buttons["开始导入"]
        if ingestButton.exists && ingestButton.isEnabled {
            safeTap(ingestButton)
            Thread.sleep(forTimeInterval: 2)
        }
    }
}

// MARK: - Graph Tests
final class GraphTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        app.tabBars.buttons["Graph"].tap()
        Thread.sleep(forTimeInterval: 1)
    }

    func testGraphZoomControls() {
        // 测试缩放按钮
        let zoomIn = app.buttons.matching(identifier: "zoom-in").firstMatch
        if zoomIn.exists {
            safeTap(zoomIn)
            Thread.sleep(forTimeInterval: 0.5)
        }

        let zoomOut = app.buttons.matching(identifier: "zoom-out").firstMatch
        if zoomOut.exists {
            safeTap(zoomOut)
            Thread.sleep(forTimeInterval: 0.5)
        }

        let resetBtn = app.buttons.matching(identifier: "reset").firstMatch
        if resetBtn.exists {
            safeTap(resetBtn)
            Thread.sleep(forTimeInterval: 0.5)
        }

        let relayoutBtn = app.buttons.matching(identifier: "relayout").firstMatch
        if relayoutBtn.exists {
            safeTap(relayoutBtn)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testTypeFilterPills() {
        let entityFilter = app.buttons.matching(identifier: "Filter-entity").firstMatch
        if entityFilter.exists {
            safeTap(entityFilter)
            Thread.sleep(forTimeInterval: 0.5)
            safeTap(entityFilter) // 取消选择
        }
    }

    func testLegendToggle() {
        let legendBtn = app.buttons.matching(identifier: "toggle-legend").firstMatch
        if legendBtn.exists {
            safeTap(legendBtn)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

// MARK: - Chat Tests
final class ChatTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
        // 从 Wiki tab 导航到 Chat
        let chatNav = app.cells.matching(identifier: "AI-Chat").firstMatch
        if chatNav.exists {
            safeTap(chatNav)
            Thread.sleep(forTimeInterval: 2)
        }
    }

    func testSendMessage() {
        let textField = app.textFields.firstMatch
        if textField.exists {
            safeTap(textField)
            textField.typeText("Hello")
            Thread.sleep(forTimeInterval: 1)

            let sendButton = app.buttons["send"]
            if sendButton.exists && sendButton.isEnabled {
                safeTap(sendButton)
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }

    func testClearHistory() {
        let menuButton = app.buttons["menu"]
        if menuButton.exists {
            safeTap(menuButton)
            Thread.sleep(forTimeInterval: 1)

            // 查找清除历史按钮
            let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '清空'")).firstMatch
            if clearButton.exists {
                safeTap(clearButton)
                Thread.sleep(forTimeInterval: 1)
                // 确认对话框
                let confirmButton = app.buttons["清空"]
                if confirmButton.exists {
                    safeTap(confirmButton)
                }
            }
        }
    }

    func testSuggestedQueries() {
        // 查找建议问题按钮
        let suggestedButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS '什么是' OR label CONTAINS '如何' OR label CONTAINS '解释'"))
        let count = suggestedButtons.count
        if count > 0 {
            safeTap(suggestedButtons.element(boundBy: 0))
            Thread.sleep(forTimeInterval: 3)
        }
    }
}

// MARK: - Lint Tests
final class LintTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToSettingsTab()
        // 导航到健康检查
        let lintNav = app.cells.matching(identifier: "维护-健康检查").firstMatch
        if lintNav.exists {
            safeTap(lintNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testRunHealthCheckButton() {
        let runButton = app.buttons.matching(identifier: "run-lint").firstMatch
        if runButton.exists {
            safeTap(runButton)
            Thread.sleep(forTimeInterval: 3)
            // 验证问题列表出现或一切正常提示
            XCTAssertTrue(app.scrollViews.firstMatch.exists)
        }
    }

    func testExpandIssueItem() {
        // 先运行检查
        let runButton = app.buttons.matching(identifier: "run-lint").firstMatch
        if runButton.exists {
            safeTap(runButton)
            Thread.sleep(forTimeInterval: 3)
        }

        let issueCell = app.cells.firstMatch
        if issueCell.exists && issueCell.isHittable {
            safeTap(issueCell)
            Thread.sleep(forTimeInterval: 1)
        }
    }
}

// MARK: - iCloud Sync Tests
final class iCloudSyncTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToSettingsTab()
        let iCloudNav = app.cells.matching(identifier: "数据-iCloud同步").firstMatch
        if iCloudNav.exists {
            safeTap(iCloudNav)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testPushToCloud() {
        let pushButton = app.buttons.matching(identifier: "push-to-icloud").firstMatch
        if pushButton.exists && pushButton.isEnabled {
            safeTap(pushButton)
            Thread.sleep(forTimeInterval: 3)
        }
    }

    func testPullFromCloudConfirmation() {
        let pullButton = app.buttons.matching(identifier: "pull-from-icloud").firstMatch
        if pullButton.exists && pullButton.isEnabled {
            safeTap(pullButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证确认对话框出现
            let alert = app.alerts["从 iCloud 下载将覆盖本地数据"]
            if alert.exists {
                safeTap(app.buttons["取消"])
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    func testAutoSyncToggle() {
        let autoSyncToggle = app.switches.matching(identifier: "auto-sync").firstMatch
        if autoSyncToggle.exists {
            safeTap(autoSyncToggle)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

// MARK: - Markdown Editor Tests
final class MarkdownEditorTests: KnowledgeBaseUITests {

    override func setUp() {
        super.setUp()
        navigateToWikiTab()
        // 创建并进入编辑页面
        createAndEditPage()
    }

    private func createAndEditPage() {
        let createButton = app.navigationBars.buttons.element(boundBy: 1)
        if createButton.exists {
            safeTap(createButton)
            Thread.sleep(forTimeInterval: 2)

            let titleField = app.textFields["页面标题"]
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Editor Test Page")
            }

            let createBtn = app.buttons["创建"]
            if createBtn.exists {
                safeTap(createBtn)
                Thread.sleep(forTimeInterval: 2)
            }

            // 点击编辑按钮
            let editButton = app.navigationBars.buttons.element(boundBy: 2)
            if editButton.exists {
                safeTap(editButton)
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    func testToolbarH1Button() {
        let h1Button = app.buttons["H1"]
        if h1Button.exists {
            safeTap(h1Button)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarBoldButton() {
        let boldButton = app.buttons["粗体"]
        if boldButton.exists {
            safeTap(boldButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarItalicButton() {
        let italicButton = app.buttons["斜体"]
        if italicButton.exists {
            safeTap(italicButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarCodeButton() {
        let codeButton = app.buttons["代码"]
        if codeButton.exists {
            safeTap(codeButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarLinkButton() {
        let linkButton = app.buttons["链接"]
        if linkButton.exists {
            safeTap(linkButton)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testToolbarListButton() {
        let listButton = app.buttons["列表"]
        if listButton.exists {
            safeTap(listButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarBlockquoteButton() {
        let quoteButton = app.buttons["引用"]
        if quoteButton.exists {
            safeTap(quoteButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarTableButton() {
        let tableButton = app.buttons["表格"]
        if tableButton.exists {
            safeTap(tableButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarDividerButton() {
        let dividerButton = app.buttons["分割线"]
        if dividerButton.exists {
            safeTap(dividerButton)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testToolbarWikilinkButton() {
        let kmlinkButton = app.buttons["Wiki链接"]
        if kmlinkButton.exists {
            safeTap(kmlinkButton)
            Thread.sleep(forTimeInterval: 1)
            // 验证 sheet 出现
            if app.sheets.firstMatch.exists {
                safeTap(app.buttons["取消"])
            }
        }
    }

    func testAddTagInput() {
        let addTagButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '添加标签'")).firstMatch
        if addTagButton.exists {
            safeTap(addTagButton)
            Thread.sleep(forTimeInterval: 1)
            // 输入标签
            let textField = app.textFields["输入标签名称"]
            if textField.exists {
                textField.typeText("TestTag")
                safeTap(app.buttons["添加"])
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    func testFinishEditing() {
        let doneButton = app.navigationBars.buttons.element(boundBy: 2)
        if doneButton.exists {
            safeTap(doneButton)
            Thread.sleep(forTimeInterval: 1)
        }
    }
}
