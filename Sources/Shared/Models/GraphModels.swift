// GraphModels.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了知识图谱（Knowledge Graph）的核心数据模型，包括节点（GraphNode）与边（GraphEdge）。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 移出 LogEntry 模型至 Logger.swift，专注于图谱业务模型。
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import CoreGraphics

// MARK: - Graph Node
struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let type: PageType
    var position: CGPoint
    var isHighlighted: Bool = false
    var communityID: Int? = nil
    var communityCohesion: Double? = nil
    var linkCount: Int = 0
}

// MARK: - Graph Edge
struct GraphEdge: Identifiable {
    let id = UUID()
    let source: UUID
    let target: UUID
}
