// SearchDiagnosticInfo.swift
//
// 作者: Wang Chong
// 功能说明: 搜索诊断数据结构
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 搜索诊断数据结构
struct SearchDiagnosticInfo: Identifiable, Equatable {
    let id = UUID()
    let query: String
    let rewrittenQuery: String
    let ftsCount: Int
    let vectorCount: Int
    let rrfTopResults: [ResultScore]
    
    struct ResultScore: Identifiable, Equatable {
        let id: UUID
        let title: String
        let ftsRank: Int
        let vectorRank: Int
        let finalScore: Double
    }
}
