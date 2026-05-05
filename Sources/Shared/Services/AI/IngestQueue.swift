// IngestQueue.swift
//
// 作者: Wang Chong
// 功能说明: 离线处理队列 (Architect 视角：高并发与后台解耦)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine
#if !os(macOS)
import BackgroundTasks
#endif

/// 离线处理队列 (Architect 视角：高并发与后台解耦)
/// 负责在大规模导入文档时，将向量化与 AI 编译任务压入后台队列，不阻塞前台 UI。
@MainActor
final class IngestQueue: ObservableObject {
    static let shared = IngestQueue()
    
    @Published var pendingCount: Int = 0
    @Published var isProcessing: Bool = false
    
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2 // 限制并发，保护移动端 NPU/电池
        queue.qualityOfService = .utility
        return queue
    }()
    
    private init() {}
    
    /// 注册后台处理任务 (Senior Dev Item #4)
    func registerBackgroundTasks() {
#if !os(macOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.zhimind.ingest.process", using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
#endif
    }
    
    /// 将导入任务加入队列
    func enqueue(title: String, content: String, llmService: any LLMServiceProtocol, pages: [WikiPage], onResult: @escaping @Sendable @MainActor (WikiPage) -> Void) {
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async { self.isProcessing = true }
            
            // 执行耗时的 AI 智能编译与向量化
            Task {
                do {
                    Logger.shared.debug("📦 [IngestQueue] 正在处理任务：\(title)")
                    let result = try await llmService.smartIngest(title: title, rawContent: content, pages: pages)
                    
                    // 更新数据库 (Fixed for Swift 6)
                    let page = WikiPage(title: title, content: result.compiledContent, tags: result.suggestedTags)
                    
                    await MainActor.run {
                        onResult(page)
                        self.decrementCount()
                    }
                } catch {
                    Logger.shared.error("❌ [IngestQueue] 任务失败：\(title), Error: \(error)")
                    await MainActor.run { self.decrementCount() }
                }
            }
        }
        
        pendingCount += 1
        operationQueue.addOperation(operation)
    }
    
    private func decrementCount() {
        pendingCount = max(0, pendingCount - 1)
        if pendingCount == 0 {
            isProcessing = false
        }
    }

    // MARK: - 后台调度逻辑
#if !os(macOS)
    private func handleBackgroundTask(task: BGProcessingTask) {
        guard pendingCount > 0 else {
            task.setTaskCompleted(success: true)
            return
        }
        
        task.expirationHandler = {
            self.operationQueue.cancelAllOperations()
        }
        
        task.setTaskCompleted(success: true)
    }
#endif
    
    func scheduleAppRefresh() {
        guard pendingCount > 0 else { return }
        
#if !os(macOS)
        let request = BGProcessingTaskRequest(identifier: "com.zhimind.ingest.process")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.error("❌ [IngestQueue] 无法调度后台任务：\(error)")
        }
#endif
    }
}

// MARK: - Sendable 合规声明
extension IngestQueue: @unchecked Sendable {}
