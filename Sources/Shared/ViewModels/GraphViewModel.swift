// GraphViewModel.swift
//
// 作者: Wang Chong
// 功能说明: Graph视图模型.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation

@MainActor
@Observable
final class GraphViewModel {
    var selectedNodeID: UUID?
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var graphSize: CGSize = CGSize(width: 400, height: 600)
    var scale: CGFloat = 1.0
    var lastScale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var isAnimating = false
    var isLayouting = false
    var showLegend = false
    var showInsights = false
    var useClustering = false
    var show3D = false
    var filterType: PageType?
    var insightSurprising: [UUID] = []
    var insightOrphans: [UUID] = []
    var insightSparse: [UUID] = []
    var insightBridges: [UUID] = []

    func getFilteredNodes() -> [GraphNode] {
        guard let filter = filterType else { return nodes }
        return nodes.filter { $0.type == filter }
    }

    func getFilteredEdges(for filteredNodes: [GraphNode]) -> [GraphEdge] {
        guard filterType != nil else { return edges }
        let filteredIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { edge in
            filteredIDs.contains(edge.source) && filteredIDs.contains(edge.target)
        }
    }
}
