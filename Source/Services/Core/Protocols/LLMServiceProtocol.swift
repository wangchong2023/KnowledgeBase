import Foundation
import Combine

/// LLM 服务协议 (架构视角：解耦重型 AI 引擎)
protocol LLMServiceProtocol: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var isProcessing: Bool { get }
    var isEnabled: Bool { get }
    
    // MARK: - 核心对话
    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage
    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error>
    func generate(prompt: String, temperature: Double) async throws -> String
    
    // MARK: - 知识维护
    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String]
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion]
    
    // MARK: - 检索增强
    func rewriteQuery(_ query: String) async -> String
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage]
    
    // MARK: - 语义处理
    func summarize(content: String) async throws -> String
    func extractActions(content: String) async throws -> String
    func generateMindMap(content: String) async throws -> String
    func generateQuiz(content: String) async throws -> String
    func generatePresentation(content: String) async throws -> String
    func generateReport(content: String) async throws -> String
    func suggestFix(issue: LintIssue, pages: [WikiPage]) async throws -> String
    func generateInsightfulQuestions(pages: [WikiPage]) async throws -> [String]
}
