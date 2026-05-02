import Foundation
import Combine

/// 图谱数据提供者协议 (Module Designer 视角：实现视图与具体 Store 的解耦)
protocol GraphDataProvider: ObservableObject {
    var pages: [WikiPage] { get }
    var clusters: [GraphClusteringService.Cluster] { get }
    var isScanningAI: Bool { get }
    
    // AI 状态
    var isAIProcessing: Bool { get }
    
    /// 触发图谱重新布局
    func requestRelayout()
}
