import Foundation

/// AI 知识综合服务 (L1 领域层)
/// 负责具体的业务 Prompt 编排与结果解析，解耦 LLMService。
final class AISynthesisService {
    static let shared = AISynthesisService()
    private let llm: LLMService
    
    private init(llm: LLMService = .shared) {
        self.llm = llm
    }
    
    /// 生成语义总结
    func summarize(content: String) async throws -> String {
        let prompt = PromptService.shared.summaryPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 生成思维导图 (Mermaid)
    func generateMindMap(content: String) async throws -> String {
        let prompt = PromptService.shared.mindmapPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 提取行动项
    func extractActions(content: String) async throws -> String {
        let prompt = PromptService.shared.actionPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 生成演示文稿大纲 (Markdown Slides)
    func generatePresentation(content: String) async throws -> String {
        let prompt = PromptService.shared.slidesPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 生成测验题
    func generateQuiz(content: String) async throws -> String {
        let prompt = PromptService.shared.quizPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }

    /// 生成信息图表 (Mermaid)
    func generateInfographic(content: String) async throws -> String {
        let prompt = PromptService.shared.infographicPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }

    /// 生成深度报告
    func generateReport(content: String) async throws -> String {
        let prompt = PromptService.shared.reportPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }

    /// 针对具体的 Lint 问题提供 AI 修复建议
    func suggestFix(issue: LintIssue, pages: [WikiPage]) async throws -> String {
        let pageTitle = pages.first(where: { $0.id == issue.pageID })?.title ?? "未知页面"
        let pageContent = pages.first(where: { $0.title == pageTitle })?.content ?? ""
        let otherTitles = pages.map { $0.title }.filter { $0 != pageTitle }
        
        let prompt = """
        \(PromptService.shared.fixSuggestionPrompt)
        
        页面标题：\(pageTitle)
        问题描述：\(issue.message)
        问题类型：\(issue.type.icon)
        
        当前页面部分内容：
        \"\"\"
        \(pageContent.prefix(500))
        \"\"\"
        
        知识库中的其他页面标题：
        \(otherTitles.prefix(50).joined(separator: ", "))
        """
        
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 自动生成启发式问题：分析知识库并推荐 3 个最值得深挖的问题
    func generateInsightfulQuestions(pages: [WikiPage]) async throws -> [String] {
        guard !pages.isEmpty else { return [] }
        
        let pageSummaries = pages.sorted(by: { $0.updated > $1.updated })
            .prefix(15)
            .map { "\($0.title): \($0.content.prefix(100))..." }
            .joined(separator: "\n")
        
        let prompt = """
        \(PromptService.shared.quizPrompt)
        
        要求：
        1. 仅返回 JSON 数组格式，例如: ["问题1", "问题2", "问题3"]
        
        知识库概览：
        \(pageSummaries)
        """
        
        let result = try await llm.generate(prompt: prompt, systemPrompt: "")
        return parseJSONArray(result)
    }
    
    private func parseJSONArray(_ text: String) -> [String] {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
}

// 补充单例支持
extension LLMService {
    static let shared = LLMService()
}
