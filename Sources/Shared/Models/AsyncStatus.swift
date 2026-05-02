import Foundation

/// 统一管理异步任务的状态枚举
enum AsyncStatus<T>: Equatable where T: Equatable {
    case idle
    case loading(String) // 带有描述信息的加载中
    case success(T)
    case failure(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
