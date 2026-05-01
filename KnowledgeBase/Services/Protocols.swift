import Foundation
import SwiftUI

// MARK: - AI 状态枚举
/// 统一管理异步任务的状态
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

// MARK: - AI 策略协议
/// 抽象 LLM 能力，支持多策略切换
protocol LLMStrategy {
    func generate(prompt: String, temperature: Double) async throws -> String
    func rewrite(query: String) async -> String
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage]
}

/// 抽象 Embedding 能力
protocol EmbeddingProvider {
    func embed(text: String) async throws -> [Float]
    func search(query: String, topK: Int) -> [(id: UUID, score: Float)]
}

// MARK: - 搜索诊断数据结构
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
