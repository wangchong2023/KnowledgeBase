// GraphLOD.swift
//
// 作者: Wang Chong
// 功能说明: 图谱语义缩放层级 (UI Designer 视角：根据视角深度动态展示)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 图谱语义缩放层级 (UI Designer 视角：根据视角深度动态展示)
enum GraphLODLevel {
    case macro    // 仅展示聚类点
    case normal   // 展示标题与链接
    case micro    // 展示内容摘要与元数据
}

struct GraphLOD {
    /// 根据当前缩放比例计算 LOD 层级
    static func level(for scale: Double) -> GraphLODLevel {
        if scale < 0.5 { return .macro }
        if scale > 2.0 { return .micro }
        return .normal
    }
}
