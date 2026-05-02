import Foundation

/// 插件权限定义
enum PluginPermission: String, Codable {
    case readContent   // 读取内容
    case writeContent  // 修改内容
    case network       // 网络访问
    case aiAccess      // 调用 LLM 服务
}

/// 插件商业化信息
struct MonetizationInfo: Codable {
    enum Model: String, Codable {
        case free       // 免费
        case donation   // 赞助/打赏
        case subscription // 订阅
    }
    var model: Model
    var supportURL: String? // 打赏链接或订阅主页
}

/// 知识库插件基础协议
protocol KnowledgePlugin: AnyObject {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var requiredPermissions: [PluginPermission] { get } // 必须声明所需权限
    var monetization: MonetizationInfo? { get }        // 商业化声明
    
    /// 插件加载：进行资源初始化、UI 锚点注册等
    func onLoad()
    
    /// 插件卸载：清理资源、注销钩子
    func onUnload()
}

/// 拦截钩子插件：允许插件干扰核心业务逻辑
protocol InterceptionPlugin: KnowledgePlugin {
    /// 在内容入库前执行（例如：执行正则清洗、敏感词过滤）
    func preProcess(content: String) -> String
    
    /// 在内容渲染前执行（例如：将特定语法转化为自定义视图）
    func postProcess(content: String) -> String
}

/// 分析服务协议：用于系统埋点与行为观测
protocol AnalyticsServiceProtocol: AnyObject {
    func trackEvent(_ name: String, properties: [String: Any]?)
    func trackError(_ error: Error, details: String?)
}
