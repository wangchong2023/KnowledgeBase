import Foundation

/// AI 策略协议 (LLM 能力抽象)
protocol LLMStrategy {
    func generate(prompt: String, temperature: Double) async throws -> String
    func rewrite(query: String) async -> String
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage]
}
