import Foundation
import Combine

/// 系统级事件总线 (Architect 视角：解耦服务间通信)
@MainActor
final class WikiEventBus {
    static let shared = WikiEventBus()
    private init() {}
    
    /// 定义系统关键事件
    enum WikiEvent {
        case pageCreated(id: UUID, title: String)
        case pageUpdated(id: UUID)
        case aiTaskStarted(type: String)
        case aiTaskCompleted(type: String, success: Bool)
        case securityStateChanged(isLocked: Bool)
        case vaultMounted(url: URL)
    }
    
    private let subject = PassthroughSubject<WikiEvent, Never>()
    
    /// 发布事件
    func publish(_ event: WikiEvent) {
        DispatchQueue.main.async {
            self.subject.send(event)
        }
    }
    
    /// 订阅事件
    func subscribe() -> AnyPublisher<WikiEvent, Never> {
        subject.eraseToAnyPublisher()
    }
}
