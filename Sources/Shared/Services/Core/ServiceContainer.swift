import Foundation

/// 依赖注入容器 (L2 层：解耦中枢)
/// 遵循 Service Locator 模式，支持 Mock 替换
@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    /// 注册服务
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    /// 解析服务
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let service = services[key] as? T else {
            fatalError("❌ [DI] 服务 \(key) 未注册！请在 App 启动时初始化。")
        }
        return service
    }
}

/// 服务注入助手
@propertyWrapper
struct Inject<T> {
    var wrappedValue: T {
        ServiceContainer.shared.resolve(T.self)
    }
}
