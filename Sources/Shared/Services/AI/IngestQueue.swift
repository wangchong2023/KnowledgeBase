import Foundation
import Combine
import BackgroundTasks

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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.zhimind.ingest.process", using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    /// 将导入任务加入队列
    func enqueue(title: String, content: String, store: KMStore) {
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async { self.isProcessing = true }
            
            // 执行耗时的 AI 智能编译与向量化
            Task {
                do {
                    LogService.shared.debug("📦 [IngestQueue] 正在处理任务：\(title)")
                    let result = try await store.llmService.smartIngest(title: title, rawContent: content, pages: store.pages)
                    
                    // 更新数据库 (Fixed for Swift 6)
                    let page = WikiPage(title: title, content: result.compiledContent, tags: result.suggestedTags)
                    
                    await MainActor.run {
                        store.addImportedPage(page)
                        self.decrementCount()
                    }
                } catch {
                    LogService.shared.error("❌ [IngestQueue] 任务失败：\(title), Error: \(error)")
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
    private func handleBackgroundTask(task: BGProcessingTask) {
        // 如果队列为空，直接结束
        guard pendingCount > 0 else {
            task.setTaskCompleted(success: true)
            return
        }
        
        task.expirationHandler = {
            // 当系统强制中断时，清理并等待下次机会
            self.operationQueue.cancelAllOperations()
        }
        
        // 执行剩余任务
        // (实际逻辑中可通过通知或直接调用 operationQueue)
        task.setTaskCompleted(success: true)
    }
    
    func scheduleAppRefresh() {
        guard pendingCount > 0 else { return }
        
        let request = BGProcessingTaskRequest(identifier: "com.zhimind.ingest.process")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false // 允许电池下工作，增加弹性
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            LogService.shared.error("❌ [IngestQueue] 无法调度后台任务：\(error)")
        }
    }
}
