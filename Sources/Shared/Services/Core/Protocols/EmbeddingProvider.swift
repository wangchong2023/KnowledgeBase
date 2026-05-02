import Foundation

/// 抽象 Embedding 能力协议
protocol EmbeddingProvider {
    func embed(text: String) async throws -> [Float]
    func search(query: String, topK: Int) -> [(id: UUID, score: Float)]
}
