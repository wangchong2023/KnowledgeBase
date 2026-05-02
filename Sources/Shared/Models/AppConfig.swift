import Foundation
import SwiftUI

/// 智元 (ZhiMind) 全局配置中心
/// 采用“动态读取 + 静态分区”模式，确保系统的高可配置性与类型安全。
enum AppConfig {
    
    // MARK: - 动态配置加载器
    private static var configData: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "AppConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }()
    
    private static func getNetwork(_ key: String) -> String {
        (configData["network"] as? [String: String])?[key] ?? ""
    }
    
    private static func getPerformance<T>(_ key: String, default: T) -> T {
        (configData["performance"] as? [String: Any])?[key] as? T ?? `default`
    }
    
    private static func getStorage(_ key: String) -> String {
        (configData["storage"] as? [String: String])?[key] ?? ""
    }

    // MARK: - 网络与服务器
    static var productionURL: String { getNetwork("plugin_market_production") }
    static var mockServerURL: String { getNetwork("plugin_market_debug") }
    static var jinaReaderURL: String { getNetwork("jina_reader_base") }
    static var ollamaDefaultURL: String { getNetwork("ollama_base") }
    static var deepseekDefaultURL: String { getNetwork("deepseek_base") }
    
    // MARK: - 性能参数
    static var searchDebounceMS: Int { getPerformance("search_debounce_ms", default: 300) }
    static var rerankTopLimit: Int { getPerformance("rerank_top_limit", default: 10) }
    static var maxLogEntries: Int { getPerformance("max_log_entries", default: 500) }
    static let historyLimit: Int = 8
    
    // MARK: - 存储
    static var logsFileName: String { getStorage("logs_filename") }
    static var pagesFileName: String { getStorage("pages_filename") }
    static var sqliteFileName: String { getStorage("sqlite_filename") }

    // MARK: - AI 检索相关阈值
    struct AI {
        static let similarityThreshold: Float = 0.35
        static let topKResults = 20
        static let summaryMaxLength = 200
        static let rewriteTemperature = 0.3
    }
    
    // MARK: - UI 交互与动画
    struct UI {
        static let graphLODZoomThreshold: CGFloat = 0.5
        static let sidebarWidth: CGFloat = 280
        static let animationDuration: Double = 0.3
        static let glassOpacity: Double = 0.15
    }

    // MARK: - 插件安全
    static let pluginThrottlingWindow: Double = 0.5
    static let maxCallsPerThrottlingWindow: Int = 50
    static let pluginTimeoutLimit: Double = 0.5
}
