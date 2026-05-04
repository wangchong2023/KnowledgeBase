// GraphModels.swift
//
// 作者: Wang Chong
// 功能说明: struct LogEntry
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

// MARK: - Log Entry
struct LogEntry: Identifiable, Codable {
    var id: UUID
    var action: LogAction
    var target: String
    var details: String
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        action: LogAction,
        target: String,
        details: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
        self.timestamp = timestamp
    }
}

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
