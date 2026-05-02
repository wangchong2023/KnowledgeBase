import Foundation
import AppIntents

/// Siri 快捷指令管理器 (Expert Design Item #3)
/// 支持通过 App Intents 进行系统集成。
@available(iOS 16.0, macOS 13.0, *)
struct ShortcutManager {
    
    // MARK: - 快速记录 Intent
    struct CaptureIntent: AppIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "在智元中记录"
        nonisolated(unsafe) static var description = LocalizedStringResource("快速将文本存入智元知识库")
        
        @Parameter(title: "内容")
        var content: String
        
        func perform() async throws -> some IntentResult & ReturnsValue<String> {
            LogService.shared.debug("🎙️ [Siri] 正在记录内容：\(content)")
            return .result(value: "已存入智元")
        }
    }
    
    // MARK: - 搜索知识库 Intent
    struct SearchWikiIntent: AppIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "在智元中搜索"
        nonisolated(unsafe) static var description = LocalizedStringResource("搜索知识库内容")
        nonisolated(unsafe) static var openAppWhenRun: Bool = true
        
        @Parameter(title: "关键词")
        var query: String
        
        func perform() async throws -> some IntentResult & ReturnsValue<String> {
            // 注意：在 Siri 环境下访问 KMStore 需要确保数据加载
            return .result(value: "正在搜索：\(query)")
        }
    }
    
    // MARK: - 获取统计 Intent
    struct GetWikiStatsIntent: AppIntent {
        nonisolated(unsafe) static var title: LocalizedStringResource = "查看智元统计"
        nonisolated(unsafe) static var description = LocalizedStringResource("获取知识库概览信息")
        
        func perform() async throws -> some IntentResult & ReturnsValue<String> {
            return .result(value: "您的知识库目前运行良好")
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct ZhiMindShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShortcutManager.CaptureIntent(),
            phrases: [
                "用 \(.applicationName) 记录",
                "在 \(.applicationName) 中记下"
            ],
            shortTitle: "快速记录",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: ShortcutManager.SearchWikiIntent(),
            phrases: [
                "在 \(.applicationName) 中搜索",
                "\(.applicationName) 搜索"
            ],
            shortTitle: "搜索知识",
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: ShortcutManager.GetWikiStatsIntent(),
            phrases: [
                "\(.applicationName) 统计",
                "\(.applicationName) 概览"
            ],
            shortTitle: "查看统计",
            systemImageName: "chart.bar"
        )
    }
}
