import Foundation
import Combine

/// LLM 服务协议 (专注于核心推理与对话)
protocol LLMServiceProtocol: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var isProcessing: Bool { get }
    var isEnabled: Bool { get }
    
    // MARK: - 核心对话与推理
    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage
    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error>
    
    /// 通用生成接口
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - systemPrompt: 可选的系统提示词
    func generate(prompt: String, systemPrompt: String) async throws -> String
    
    // MARK: - 知识维护
    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String]
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion]
    
    // MARK: - 检索增强
    func rewriteQuery(_ query: String) async -> String
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage]
}
