import Foundation
import Combine

/// 任务类型
enum TaskType: String, CaseIterable {
    case ai         // AI 任务
    case ingest     // 导入任务
    
    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .ingest: return "tray.and.arrow.down"
        }
    }
}

/// 任务执行状态
enum TaskStatus: Equatable {
    case pending                    // 等待中
    case running(progress: Double)  // 执行中（带进度）
    case completed                  // 已完成
    case failed(error: String)      // 执行失败（带错误信息）
    
    static func == (lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.completed, .completed): return true
        case (.running(let p1), .running(let p2)): return p1 == p2
        case (.failed(let e1), .failed(let e2)): return e1 == e2
        default: return false
        }
    }
}

/// 全球异步任务模型
struct GlobalTask: Identifiable {
    let id = UUID()
    let type: TaskType
    let name: String                // 任务名称
    let target: String              // 目标对象
    var status: TaskStatus          // 当前状态
    let startTime = Date()          // 启动时间
    var isRead: Bool = false        // 用户是否已读（用于通知红点）
    var associatedPageID: UUID? = nil // 关联页面（完成后可跳转）
}

/// 全局任务管理中心 (单例)
/// 负责全库异步 AI 任务及导入任务的生命周期管理、状态追踪与自动清理。
@MainActor
class TaskCenter: ObservableObject {
    static let shared = TaskCenter()
    
    @Published var tasks: [GlobalTask] = []
    @Published var latestStatus: String = ""
    
    /// 更新全局最新状态文案 (用于触发 UI 脉搏动效)
    func updateLatestStatus(_ text: String) {
        self.latestStatus = text
    }
    
    /// 未读已完成任务数
    var unreadCount: Int {
        tasks.filter { task in
            if task.isRead { return false }
            switch task.status {
            case .completed, .failed:
                return true
            default:
                return false
            }
        }.count
    }
    
    func addTask(type: TaskType = .ai, name: String, target: String) -> UUID {
        let task = GlobalTask(type: type, name: name, target: target, status: .pending)
        self.tasks.insert(task, at: 0)
        self.latestStatus = Localized.trf("aitask.status.startingFormat", name, target)
        
        // 灵动岛适配：启动实时活动
        ActivityService.shared.startActivity(name: name, target: target)
        
        return task.id
    }
    
    func updateTask(_ id: UUID, status: TaskStatus, associatedPageID: UUID? = nil) {
        if let index = self.tasks.firstIndex(where: { $0.id == id }) {
            self.tasks[index].status = status
            if let pageID = associatedPageID {
                self.tasks[index].associatedPageID = pageID
            }
            
            let task = self.tasks[index]
            switch status {
            case .running(let progress):
                self.latestStatus = Localized.trf("aitask.status.runningFormat", task.name, task.target)
                ActivityService.shared.updateProgress(progress, message: self.latestStatus)
            case .completed:
                self.latestStatus = Localized.trf("aitask.status.completedFormat", task.name)
                // 发送本地通知（如果用户不在任务中心）
                NotificationCenter.default.post(name: .taskCompleted, object: task)
                ActivityService.shared.endActivity()
            case .failed:
                self.latestStatus = Localized.trf("aitask.status.failedFormat", task.name)
                NotificationCenter.default.post(name: .taskCompleted, object: task)
                ActivityService.shared.endActivity()
            case .pending:
                break
            }
            
            // 如果成功且任务过多，清理旧任务
            if case .completed = status {
                if self.tasks.count > 20 {
                    self.tasks.removeLast()
                }
            }
        }
    }
    
    func markAsRead(_ id: UUID) {
        DispatchQueue.main.async {
            if let index = self.tasks.firstIndex(where: { $0.id == id }) {
                self.tasks[index].isRead = true
            }
        }
    }
    
    func markAllAsRead() {
        for i in 0..<self.tasks.count {
            self.tasks[i].isRead = true
        }
    }
    
    func removeTask(_ id: UUID) {
        DispatchQueue.main.async {
            self.tasks.removeAll(where: { $0.id == id })
        }
    }
}

extension NSNotification.Name {
    static let taskCompleted = NSNotification.Name("km_task_completed")
}
