// ServiceContainer.swift
//
// 作者: Wang Chong
// 功能说明: 依赖注入容器 (L2 层：解耦中枢)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 依赖注入容器 (L2 层：解耦中枢)
/// 遵循 Service Locator 模式，支持 Mock 替换
final class ServiceContainer: @unchecked Sendable {
    static let shared = ServiceContainer()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    /// 注册服务
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    /// 重置所有服务（主要用于测试环境隔离）
    func reset() {
        services.removeAll()
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
