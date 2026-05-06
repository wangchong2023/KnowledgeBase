// GraphDataProvider.swift
//
// 作者: Wang Chong
// 功能说明: 图谱数据提供者协议 (Module Designer 视角：实现视图与具体 Store 的解耦)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
