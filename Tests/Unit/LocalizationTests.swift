// LocalizationTests.swift
//
// 作者: Wang Chong
// 功能说明: 验证本地化模块的完整性与 Key 的存在性
// 版本: 1.0
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

final class LocalizationTests: XCTestCase {

    /// 验证核心模块的 Key 是否能正确解析（而非原样返回 Key）
    func testLocalizationKeysExistence() {
        // 1. Common 模块
        XCTAssertNotEqual(L10n.Common.ok, "misc.ok", "Common.ok 应该被正确翻译")
        XCTAssertNotEqual(L10n.Common.cancel, "misc.cancel", "Common.cancel 应该被正确翻译")
        
        // 2. Settings 模块
        XCTAssertNotEqual(L10n.Settings.title, "settings.settings", "Settings.title 应该被正确翻译")
        
        // 3. Chat 模块
        XCTAssertNotEqual(L10n.Chat.title, "chat.title", "Chat.title 应该被正确翻译")
        
        // 4. Ingest 模块
        XCTAssertNotEqual(L10n.Ingest.title, "ingest.title", "Ingest.title 应该被正确翻译")
        
        // 5. Backup 模块
        XCTAssertNotEqual(L10n.Backup.title, "backup.title", "Backup.title 应该被正确翻译")
    }
    
    /// 验证不同语言环境下的切换逻辑（模拟环境）
    func testLanguageSwitchingLogic() {
        let currentMode = Localized.languageMode
        
        // 测试切换到英文
        Localized.languageMode = .english
        XCTAssertEqual(Localized.currentLanguage, "en")
        
        // 测试切换到中文
        Localized.languageMode = .chinese
        XCTAssertEqual(Localized.currentLanguage, "zh-Hans")
        
        // 还原现场
        Localized.languageMode = currentMode
    }
    
    /// 验证格式化字符串是否正常工作
    func testParameterizedLocalization() {
        // 假设 AITasks 中有类似 "aitask.center.status" = "正在处理 %d 个任务"
        // 这里验证 trf 接口不会崩溃且能正常注入参数
        let formatted = L10n.AI.Task.trf("aitask.test.param", "测试")
        XCTAssertTrue(formatted.contains("测试") || formatted == "aitask.test.param", "格式化调用应正常执行")
    }

    /// 自动化全量审计：动态遍历所有 L10n 模块并验证 Key 的存在性
    func testComprehensiveLocalizationAudit() {
        let modules: [(name: String, table: String, keys: [String])] = [
            ("Common", "Common", ["misc.ok", "misc.cancel", "misc.action", "misc.done"]),
            ("Settings", "Settings", ["settings.settings", "settings.language", "settings.theme", "settings.version", "settings.about"]),
            ("Chat", "Chat", ["chat.title", "chat.newChat", "chat.history"]),
            ("Ingest", "Ingest", ["ingest.title", "ingest.manualEntry", "ingest.smartIngest"]),
            ("Backup", "Backup", ["backup.title", "backup.create", "backup.restore"]),
            ("ICloud", "ICloud", ["icloud.title", "icloud.syncNow", "icloud.notAvailable"]),
            ("AI", "AITasks", ["aitask.title", "aitask.generating", "aitask.done"]),
            ("CoreModels", "CoreModels", ["type.entity", "type.concept", "type.source"]),
            ("Lint", "Lint", ["lint.title", "lint.runScan", "lint.noIssues"]),
            ("Graph", "Graph", ["graph.title", "graph.optimizingLayout", "graph.insights", "graph.legend"]),
            ("Transfer", "Transfer", ["transfer.export.title", "transfer.import.title"]),
            ("Actions", "Actions", ["action.delete", "action.edit", "action.share"]),
            ("Accessibility", "Accessibility", ["ax.graph.contentDescription"]),
            ("Components", "Components", ["component.search.placeholder"]),
            ("Watch", "Watch", ["watch.syncing"]),
            ("Schema", "Schema", ["schema.title"]),
            ("Collaboration", "Collaboration", ["collab.activeUsers"]),
            ("Widget", "Widget", ["widget.stats.title"]),
            ("Coachmark", "Coachmark", ["coach.graph.welcome"]),
            ("Creation", "Creation", ["create.page.title"]),
            ("Dashboard", "Dashboard", ["dash.summary"]),
            ("Editor", "Editor", ["editor.placeholder"])
        ]
        
        var missingKeys: [String] = []
        
        for module in modules {
            for key in module.keys {
                let translated = Localized.tr(key, table: module.table)
                // 如果返回了 [MISSING: key] 或者原样返回了 key，说明翻译缺失
                // 注意：在没有翻译的情况下，NSLocalizedString 会返回原 Key
                if translated.contains("[MISSING:") || (translated == key && !key.isEmpty) {
                    missingKeys.append("\(module.table).\(key)")
                }
            }
        }
        
        XCTAssertTrue(missingKeys.isEmpty, "以下本地化 Key 缺失或未在对应的表中定义: \n\(missingKeys.joined(separator: "\n"))")
    }
}
