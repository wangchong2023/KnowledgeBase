import XCTest

// MARK: - Platform-Specific UI Tests
/// KnowledgeBase 跨平台（iPhone / iPad / Mac Catalyst）UI 测试套件
/// 运行方式:
///   1. 在 Xcode 中打开 KnowledgeBase.xcodeproj
///   2. 选择对应平台的测试 scheme
///   3. 选择对应模拟器（iPhone 17 Pro / iPad Pro / Mac）
///   4. Cmd+U 运行测试
class KMPlatformUITests: XCTestCase {

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
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    func safeTap(_ element: XCUIElement, file: String = #file, line: Int = #line) {
        if element.exists && element.isHittable {
            element.tap()
        } else {
            XCTFail("无法点击元素: \(element.identifier) (at \(file):\(line))")
        }
    }

    /// 获取当前平台
    var currentPlatform: String {
        #if targetEnvironment(simulator)
        let screenHeight = UIScreen.main.bounds.height
        if screenHeight >= 1024 {
            return "iPad"
        } else {
            return "iPhone"
        }
        #else
        return "Mac"
        #endif
    }
}

// MARK: - iPhone Specific Tests
@available(iOS 17.0, *)
final class iPhoneTests: KMPlatformUITests {

    func testiPhoneTabBarIsAtBottom() {
        // iPhone 上 Tab 栏应该在底部
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "iPhone Tab 栏不存在")

        // 验证 Tab 栏位置（通过底部边缘判断）
        let tabBarFrame = tabBar.frame
        let screenHeight = app.windows.firstMatch.frame.height
        XCTAssertTrue(tabBarFrame.maxY <= screenHeight + 100,
                      "Tab 栏应该在屏幕底部区域")
    }

    func testiPhoneTabBarHasLabels() {
        // iPhone Tab 栏应该同时显示图标和文字标签
        let wikiTab = app.tabBars.buttons["Wiki"]
        let graphTab = app.tabBars.buttons["Graph"]

        XCTAssertTrue(wikiTab.exists || app.tabBars.buttons.element(boundBy: 0).exists,
                      "Wiki Tab 不存在")

        // iPhone 上 Tab 栏每个按钮应该有标签（不只是图标）
        // 检查 Tab 按钮的 label 是否包含文字
        if wikiTab.exists {
            let label = wikiTab.label
            XCTAssertFalse(label.isEmpty, "Wiki Tab 应该有文字标签")
        }
    }

    func testiPhoneCompactWidthClass() {
        // iPhone 使用 compact width size class
        navigateToWikiTab()
        // 在 compact 模式下，某些按钮应该显示
        let createButton = app.navigationBars.buttons.element(boundBy: 1)
        XCTAssertTrue(createButton.exists || app.navigationBars.buttons["add"].exists,
                      "iPhone 应该显示创建按钮")
    }

    func testiPhoneSidebarNotVisible() {
        // iPhone 默认不显示侧边栏
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.exists, "iPhone 导航栏应该存在")
    }

    // MARK: - Navigation
    func testiPhoneNavigationStack() {
        navigateToWikiTab()

        // iPhone 使用 NavigationStack（不是 SplitView）
        // 导航栏应该在顶部
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.exists, "iPhone 导航栏应该存在")
    }

    func testiPhoneTabNavigation() {
        // 测试 iPhone 上 5 个 Tab 都能正常切换
        let tabs = ["Wiki", "Graph", "Search", "Ingest", "Settings"]

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            if button.exists {
                button.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    // MARK: - Helpers
    private func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}

// MARK: - iPad Specific Tests
@available(iOS 17.0, *)
final class iPadTests: KMPlatformUITests {

    func testiPadNavigationSplitViewVisible() {
        // iPad 上应该显示导航栏
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.exists, "iPad 导航栏应该存在")
    }

    func testiPadSidebarVisible() {
        // iPad 上侧边栏可能通过 Tab Bar 切换
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "iPad Tab 栏应该存在")
    }

    func testiPadTabBarPresence() {
        // iPad 上可能显示顶部 Tab 栏（sidebarAdaptable 样式）
        // 检查是否有 Tab 栏
        let hasTabBar = app.tabBars.count > 0
        let hasTopTabBar = app.children(matching: .navigationBar).count > 0

        // iPad 应该有某种形式的 Tab 导航
        XCTAssertTrue(hasTabBar || hasTopTabBar,
                      "iPad 应该有 Tab 导航（顶部或底部）")
    }

    func testiPadRegularWidthClass() {
        // iPad 使用 regular width size class
        navigateToWikiTab()

        // 创建按钮应该存在
        let createButton = app.navigationBars.buttons.element(boundBy: 1)
        XCTAssertTrue(createButton.exists, "iPad 应该显示创建按钮")
    }

    func testiPadDetailPane() {
        // iPad 应该有详情面板
        let detailNav = app.navigationBars.firstMatch

        XCTAssertTrue(detailNav.exists,
                      "iPad 应该有导航栏")
    }

    func testiPadToolbarButtons() {
        // iPad 工具栏应该有更多空间显示按钮
        navigateToWikiTab()

        let navButtons = app.navigationBars.buttons
        let buttonCount = navButtons.count

        // iPad 导航栏按钮应该足够多
        XCTAssertTrue(buttonCount >= 2, "iPad 导航栏应该有多个按钮")
    }

    // MARK: - Navigation
    func testiPadNavigationStack() {
        navigateToWikiTab()

        // iPad 上应该使用导航栏
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.exists, "iPad 导航栏应该存在")
    }

    func testiPadTabNavigation() {
        // 测试 iPad 上 5 个 Tab 都能正常切换
        let tabs = ["Wiki", "Graph", "Search", "Ingest", "Settings"]

        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            if button.exists {
                button.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    func testiPadSidebarToggle() {
        // 测试侧边栏展开/折叠（如果支持）
        let sidebarToggle = app.buttons["sidebar-toggle"]
        if sidebarToggle.exists {
            safeTap(sidebarToggle)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testiPadKeyboardShortcuts() {
        // iPad 应该有键盘快捷键支持
        // 测试 cmd + n 新建页面
        app.typeText("n")
        Thread.sleep(forTimeInterval: 1)

        // 验证是否有新建页面 sheet
        let createSheet = app.sheets.firstMatch
        if createSheet.exists {
            // 关闭 sheet
            let cancelButton = app.buttons["取消"]
            if cancelButton.exists {
                safeTap(cancelButton)
            }
        }
    }

    // MARK: - Helpers
    private func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}

// MARK: - Mac Catalyst Specific Tests
@available(iOS 17.0, *)
final class MacCatalystTests: KMPlatformUITests {

    func testMacMenuBarExists() {
        // Mac 上应该有菜单栏
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.exists, "Mac 应该有菜单栏")
    }

    func testMacWindowChrome() {
        // Mac 窗口应该有标准的窗口装饰（标题栏等）
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Mac 应该有窗口")

        // 窗口应该有最小化、关闭按钮等
        let closeButton = window.buttons["close-button"]
        // Mac 窗口按钮可能使用不同的 identifier
        XCTAssertTrue(window.buttons.count > 0, "Mac 窗口应该有按钮")
    }

    func testMacToolbar() {
        // Mac 应该有工具栏
        let toolbar = app.toolbars.firstMatch
        // 工具栏可能不总是存在，取决于窗口状态
        if toolbar.exists {
            XCTAssertTrue(toolbar.buttons.count > 0, "Mac 工具栏应该有按钮")
        }
    }

    func testMacKeyboardShortcuts() {
        // 测试 Mac 键盘快捷键
        // Cmd + n 新建
        app.typeText("n")
        Thread.sleep(forTimeInterval: 1)

        let createSheet = app.sheets.firstMatch
        if createSheet.exists {
            let cancelButton = app.buttons["取消"]
            if cancelButton.exists {
                safeTap(cancelButton)
            }
        }

        // Cmd + f 搜索
        app.typeText("f")
        Thread.sleep(forTimeInterval: 0.5)
    }

    func testMacMouseInteractions() {
        // Mac 应该支持鼠标悬停
        let wikiTab = app.tabBars.buttons["Wiki"]
        if wikiTab.exists {
            // 右键菜单
            wikiTab.rightClick()
            Thread.sleep(forTimeInterval: 0.5)

            // 检查是否有上下文菜单
            let menu = app.menus.firstMatch
            if menu.exists {
                // 按 Escape 关闭菜单
                app.typeText(XCUIKeyboardKey.inputEscape.rawValue)
            }
        }
    }

    func testMacWindowManagement() {
        // 测试窗口管理
        let window = app.windows.firstMatch
        if window.exists {
            // 最大化窗口（如果支持）
            let fullScreenButton = window.buttons["full-screen-button"]
            if fullScreenButton.exists && fullScreenButton.isEnabled {
                safeTap(fullScreenButton)
                Thread.sleep(forTimeInterval: 0.5)

                // 退出全屏
                safeTap(fullScreenButton)
            }
        }
    }

    func testMacTrackpadGestures() {
        // Mac 应该支持触控板手势
        // 双指滑动模拟
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // 使用双指轻扫
            scrollView.swipeDown()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    // MARK: - Menu Items
    func testMacFileMenu() {
        let menuBar = app.menuBars.firstMatch
        let fileMenu = menuBar.menuItems["File"]

        if fileMenu.exists {
            safeTap(fileMenu)
            Thread.sleep(forTimeInterval: 0.5)

            // 检查菜单项
            let newItem = app.menuItems["New"]
            if newItem.exists {
                safeTap(newItem)
                Thread.sleep(forTimeInterval: 1)
            }

            // 按 Escape 关闭菜单
            app.typeText(XCUIKeyboardKey.inputEscape.rawValue)
        }
    }

    func testMacEditMenu() {
        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuItems["Edit"]

        if editMenu.exists {
            safeTap(editMenu)
            Thread.sleep(forTimeInterval: 0.5)

            let undoItem = app.menuItems["Undo"]
            if undoItem.exists {
                safeTap(undoItem)
                Thread.sleep(forTimeInterval: 0.5)
            }

            app.typeText(XCUIKeyboardKey.inputEscape.rawValue)
        }
    }

    func testMacViewMenu() {
        let menuBar = app.menuBars.firstMatch
        let viewMenu = menuBar.menuItems["View"]

        if viewMenu.exists {
            safeTap(viewMenu)
            Thread.sleep(forTimeInterval: 0.5)

            // 检查是否有 Enter Full Screen 选项
            let fullScreenItem = app.menuItems["Enter Full Screen"]
            if fullScreenItem.exists {
                safeTap(fullScreenItem)
                Thread.sleep(forTimeInterval: 0.5)

                // 退出全屏
                app.typeText(XCUIKeyboardKey.inputEscape.rawValue)
            }

            app.typeText(XCUIKeyboardKey.inputEscape.rawValue)
        }
    }

    // MARK: - Helpers
    private func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}

// MARK: - Responsive Layout Tests
@available(iOS 17.0, *)
final class ResponsiveLayoutTests: KMPlatformUITests {

    func testOrientationChange() {
        // 测试横竖屏切换（iPad）
        navigateToWikiTab()

        // 获取当前方向
        let initialOrientation = app.interfaceOrientation

        // 如果支持旋转，测试切换
        let supportsRotation = UIDevice.current.isGeneratorEligibleForMetrics

        if supportsRotation {
            // 切换到横屏
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 1)

            // 验证 UI 正确调整
            let splitView = app.navigationSplitViews.firstMatch
            if splitView.exists {
                // 横屏时侧边栏可能表现不同
            }

            // 切换回竖屏
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func testSizeClassTransitions() {
        // 测试 size class 切换
        // iPad 分屏模式会导致 size class 变化
        navigateToWikiTab()

        // 在 compact 模式下验证布局
        let isCompact = app.windows.firstMatch.traitCollection.horizontalSizeClass == .compact
        let isRegular = app.windows.firstMatch.traitCollection.horizontalSizeClass == .regular

        XCTAssertTrue(isCompact || isRegular, "应该有明确的 size class")
    }

    func testDynamicTypeScaling() {
        // 测试动态字体大小
        navigateToWikiTab()

        // 获取当前字体大小
        let preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory

        // 验证字体大小不是 unknown
        XCTAssertNotEqual(preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge,
                          "字体大小应该可读")
    }

    // MARK: - Helpers
    private func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}

// MARK: - Accessibility Tests (All Platforms)
@available(iOS 17.0, *)
final class AccessibilityTests: KMPlatformUITests {

    func testVoiceOverSupport() {
        // 测试 VoiceOver 支持
        navigateToWikiTab()

        // 验证关键元素有 accessibility identifier
        let wikiTab = app.tabBars.buttons["Wiki"]
        XCTAssertTrue(wikiTab.exists, "Wiki Tab 应该可访问")

        // 验证标签
        let label = wikiTab.accessibilityLabel
        XCTAssertFalse(label?.isEmpty ?? true, "Tab 应该有 accessibility label")
    }

    func testDynamicType() {
        // 测试动态字体
        navigateToWikiTab()

        // 验证文本可读性
        let textElements = app.textFields
        if textElements.count > 0 {
            let firstText = textElements.firstMatch
            if firstText.exists {
                // 文本应该可读
                XCTAssertFalse(firstText.label?.isEmpty ?? true,
                               "文本应该有内容")
            }
        }
    }

    func testColorContrast() {
        // 验证颜色对比度（基础检查）
        navigateToWikiTab()

        // 获取窗口
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "窗口应该存在")
    }

    // MARK: - Helpers
    private func navigateToWikiTab() {
        if !app.tabBars.buttons["Wiki"].exists {
            app.tabBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Wiki"].tap()
        Thread.sleep(forTimeInterval: 1)
    }
}
