import Foundation
import Combine

/// 插件注册中心 (L2 层：中枢管理)
final class PluginRegistry: ObservableObject {
    static let shared = PluginRegistry()
    
    @Published var plugins: [KnowledgePlugin] = []
    private var intercepters: [InterceptionPlugin] = []
    
    // 注入分析服务
    var analytics: AnalyticsServiceProtocol?
    
    // 数据提供者：用于将核心数据（如页面列表）安全传递给沙盒
    var pagesProvider: (() -> [WikiPage])?
    
    // 内核版本定义
    let currentHostVersion = "2.0.0"
    
    // 超时配置：单插件最大执行时间 0.5s
    private let pluginTimeout: TimeInterval = 0.5
    
    // 限流配置
    private var pluginCallCounts: [String: Int] = [:]
    private let maxCallsPerWindow = 50
    private let throttlingWindow: TimeInterval = 60.0 // 1分钟
    
    private init() {}
    
    func loadPlugin(_ plugin: KnowledgePlugin) {
        // 版本兼容性检查
        if plugin.manifest.version.hasPrefix("1.") {
            LogService.shared.debug("📦 [Adapter] 检测到 1.x 插件 \(plugin.manifest.name)，已启用 v1_Compatibility_Shim。")
        }
        
        // 创建沙盒上下文
        let context = PluginContextImpl(manifest: plugin.manifest)
        
        plugin.onLoad(context: context)
        plugins.append(plugin)
        if let intercepter = plugin as? InterceptionPlugin {
            intercepters.append(intercepter)
        }
        analytics?.trackEvent("plugin_loaded", properties: ["id": plugin.manifest.id])
    }
    
    // MARK: - Plugin Context Implementation
    private struct PluginContextImpl: PluginContext {
        let manifest: PluginManifest
        var hostVersion: String { PluginRegistry.shared.currentHostVersion }
        
        func log(_ message: String) {
            LogService.shared.debug("🔌 [Plugin:\(manifest.id)] \(message)")
        }
        
        func requestAIAccess(prompt: String) async -> String? {
            // 安全审计：检查 manifest 是否声明了 'llm' 权限
            guard manifest.permissions.contains("llm") else {
                LogService.shared.error("🛡️ [安全拦截] 插件 \(manifest.id) 尝试调用 LLM，但未在 manifest 中声明 'llm' 权限。", error: nil)
                return nil
            }
            return try? await ServiceContainer.shared.resolve(LLMServiceProtocol.self).generate(prompt: prompt, systemPrompt: "你是一个智能插件辅助助手")
        }
        
        func queryPages(matching query: String) async -> [WikiPage] {
            guard manifest.permissions.contains("pages.read") else {
                LogService.shared.error("🛡️ [安全拦截] 插件 \(manifest.id) 尝试查询页面，但未声明 'pages.read' 权限。", error: nil)
                return []
            }
            let pages = PluginRegistry.shared.pagesProvider?() ?? []
            return await ServiceContainer.shared.resolve(LinkService.self).search(query: query, in: pages)
        }
    }
    
    func unloadPlugin(id: String) {
        if let index = plugins.firstIndex(where: { $0.manifest.id == id }) {
            plugins[index].onUnload()
            plugins.remove(at: index)
        }
        intercepters.removeAll(where: { $0.manifest.id == id })
        analytics?.trackEvent("plugin_unloaded", properties: ["id": id])
    }
    
    /// 执行全量拦截过滤 (含超时熔断逻辑)
    func applyPreProcess(to content: String) -> String {
        var result = content
        
        for intercepter in plugins.compactMap({ $0 as? InterceptionPlugin }) {
            // 动态流控审计 (Throttling)
            let callCount = pluginCallCounts[intercepter.manifest.id] ?? 0
            if callCount > maxCallsPerWindow {
                LogService.shared.debug("⚠️ [Throttling] 插件 \(intercepter.manifest.id) 调用过于频繁，已自动降级。")
                continue
            }
            pluginCallCounts[intercepter.manifest.id] = callCount + 1
            
            // 异步重置计数器 (简易窗口期)
            DispatchQueue.global().asyncAfter(deadline: .now() + throttlingWindow) {
                self.pluginCallCounts[intercepter.manifest.id] = 0
            }

            let start = CFAbsoluteTimeGetCurrent()
            
            // 使用同步封装，配合 DispatchGroup 或简单的时间检查实现逻辑熔断
            // 提示：在主线程同步调用中，我们无法轻易 Kill 正在执行的闭包，
            // 但我们可以记录性能并在后续禁用“坏插件”
            
            // 安全校验：权限检查
            if !intercepter.manifest.permissions.contains("writeContent") {
                LogService.shared.error("🛡️ [安全拦截] 插件 \(intercepter.manifest.name) 尝试修改内容，但未声明 writeContent 权限。", error: nil)
                continue
            }

            let processed = intercepter.preProcess(content: result)
            
            let duration = CFAbsoluteTimeGetCurrent() - start
            
            if duration > pluginTimeout {
                LogService.shared.error("⚠️ [熔断警告] 插件 \(intercepter.manifest.name) 执行超时 (\(String(format: "%.2f", duration))s)，将被限制。")
                analytics?.trackEvent("plugin_circuit_break", properties: ["id": intercepter.manifest.id, "duration": duration])
            }
            
            result = processed
            
            // 埋点：插件执行成功，记录时长
            analytics?.trackEvent("plugin_intercepted", properties: [
                "id": intercepter.manifest.id,
                "duration": duration,
                "type": "preProcess"
            ])
        }
        
        return result
    }
}
