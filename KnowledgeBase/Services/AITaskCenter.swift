import Foundation
import Combine

enum AITaskStatus {
    case pending
    case running(progress: Double)
    case completed
    case failed(error: String)
}

struct AITask: Identifiable {
    let id = UUID()
    let name: String
    let target: String
    var status: AITaskStatus
    let startTime = Date()
}

class AITaskCenter: ObservableObject {
    static let shared = AITaskCenter()
    
    @Published var tasks: [AITask] = []
    
    func addTask(name: String, target: String) -> UUID {
        let task = AITask(name: name, target: target, status: .pending)
        DispatchQueue.main.async {
            self.tasks.insert(task, at: 0)
        }
        return task.id
    }
    
    func updateTask(_ id: UUID, status: AITaskStatus) {
        DispatchQueue.main.async {
            if let index = self.tasks.firstIndex(where: { $0.id == id }) {
                self.tasks[index].status = status
                
                // 如果成功且任务过多，清理旧任务
                if case .completed = status {
                    if self.tasks.count > 20 {
                        self.tasks.removeLast()
                    }
                }
            }
        }
    }
    
    func removeTask(_ id: UUID) {
        DispatchQueue.main.async {
            self.tasks.removeAll(where: { $0.id == id })
        }
    }
}
