// WikiEventBus.swift
//
// 作者: Wang Chong
// 功能说明: 系统级事件总线 (Architect 视角：解耦服务间通信)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine

/// 系统级事件总线 (Architect 视角：解耦服务间通信)
@MainActor
final class WikiEventBus {
    static let shared = WikiEventBus()
    private init() {}
    
    /// 定义系统关键事件
    enum WikiEvent {
        case pageCreated(id: UUID, title: String, nodeCount: Int, linkCount: Int)
        case pageUpdated(id: UUID, nodeCount: Int, linkCount: Int)
        case pagesCleared
        case clearAllDataRequested // 新增：全局数据清理请求
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

extension WikiEventBus: @unchecked Sendable {}
