// EmbeddingProvider.swift
//
// 作者: Wang Chong
// 功能说明: 抽象 Embedding 能力协议
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 抽象 Embedding 能力协议
protocol EmbeddingProvider {
    func embed(text: String) async throws -> [Float]
    func search(query: String, topK: Int) -> [(id: UUID, score: Float)]
}
