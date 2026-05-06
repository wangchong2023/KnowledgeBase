// AISynthesisService.swift
//
// 作者: Wang Chong
// 功能说明: AI 知识综合服务 (L1 领域层)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// AI 知识综合服务 (L1 领域层)
/// 负责具体的业务 Prompt 编排与结果解析，解耦 LLMService。
@MainActor
final class AISynthesisService {
    static let shared = AISynthesisService()
    
    @Inject private var llm: LLMService
    
    private init() {
        ServiceContainer.shared.register(self, for: AISynthesisService.self)
    }
    
    func summarize(content: String) async throws -> String {
        let prompt = PromptService.shared.summaryPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let result = try await llm.generate(prompt: prompt, systemPrompt: "")
        return SynthesisProcessor.cleanMarkdown(result)
    }
    
    /// 生成思维导图 (Mermaid)
    func generateMindMap(content: String) async throws -> String {
        let prompt = PromptService.shared.mindmapPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let systemPrompt = """
        You are a Mermaid mindmap expert. 
        Always start with '# <Summary Title>'.
        Then follow with the Mermaid code starting strictly with 'mindmap'.
        Indent with 2 spaces.
        Do NOT use code fences (```).
        """
        let result = try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
        return SynthesisProcessor.formatMermaid(result, fallbackPrefix: "mindmap")
    }
    
    func extractActions(content: String) async throws -> String {
        let prompt = PromptService.shared.actionPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let result = try await llm.generate(prompt: prompt, systemPrompt: "")
        return SynthesisProcessor.cleanMarkdown(result)
    }
    
    func generatePresentation(content: String) async throws -> String {
        let prompt = PromptService.shared.slidesPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a presentation expert. Use Markdown. Use '# ' for Title slide, '## ' for new slides. Use bullet points.")
        return SynthesisProcessor.cleanMarkdown(result)
    }

    /// 将 Markdown 转换为 PPTX 文件
    func convertToPPTX(markdown: String, title: String) async throws -> URL {
        return try await WebViewExportService.shared.exportToPPTX(markdown: markdown, fileName: title)
    }
    
    /// 生成测验题
    func generateQuiz(content: String) async throws -> String {
        let prompt = PromptService.shared.quizPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let quizTitle = Localized.tr("prompt.quiz.defaultTitle")
        let questionLabel = Localized.tr("prompt.quiz.question")
        let optionLabel = Localized.tr("prompt.quiz.option")
        let explanationLabel = Localized.tr("prompt.quiz.explanation")
        
        let jsonFormat = """
        {"title":"\(quizTitle)","questions":[{"id":0,"text":"\(questionLabel)?","options":["\(optionLabel) A","\(optionLabel) B","\(optionLabel) C","\(optionLabel) D"],"answer":0,"explanation":"\(explanationLabel)"}]}
        """
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a quiz generator. Output ONLY valid JSON (no markdown fences) in this exact format: \(jsonFormat). answer is 0-based index (0=A,1=B,2=C,3=D). explanation tells why the answer is correct. Do NOT wrap in ```json```.")

        // 使用专用的 QuizProcessor 进行处理
        if QuizProcessor.canDecodeAsQuizModel(result) {
            return result
        }

        if let formatted = QuizProcessor.convertJSONToMarkdown(result) {
            return formatted
        }

        return result
    }

    /// 生成信息图表 (Mermaid)
    func generateInfographic(content: String) async throws -> String {
        let prompt = PromptService.shared.infographicPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let systemPrompt = """
        You are a senior data visualization expert. 
        Create a professional Mermaid graph TD structure.
        Always start with '# <Summary Title>'.
        Do NOT use code fences (```). 
        Only output the Title and the Mermaid code.
        """
        let result = try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
        return SynthesisProcessor.formatMermaid(result, fallbackPrefix: "graph TD")
    }
    
    func generateReport(content: String) async throws -> String {
        let prompt = PromptService.shared.reportPrompt + PromptService.shared.languageInstruction + "\n\n内容：\n\(content)"
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a report writer. First line MUST be '# <title>' summarizing the report topic. Use Markdown headings for sections.")
        return SynthesisProcessor.cleanMarkdown(result)
    }

    /// 针对具体的 Lint 问题提供 AI 修复建议
    func suggestFix(issue: LintIssue, pages: [WikiPage]) async throws -> String {
        let pageTitle = pages.first(where: { $0.id == issue.pageID })?.title ?? L10n.Common.tr("unknown")
        let pageContent = pages.first(where: { $0.title == pageTitle })?.content ?? ""
        let otherTitles = pages.map { $0.title }.filter { $0 != pageTitle }
        
        let prompt = """
        \(PromptService.shared.fixSuggestionPrompt)
        \(PromptService.shared.languageInstruction)
        
        \(Localized.tr("llm.prompt.pageTitle"))：\(pageTitle)
        \(Localized.tr("llm.prompt.issueDesc"))：\(issue.message)
        \(Localized.tr("llm.prompt.issueType"))：\(issue.type.icon)
        
        \(Localized.tr("llm.prompt.pageContentSnippet"))：
        \"\"\"
        \(pageContent.prefix(500))
        \"\"\"
        
        \(Localized.tr("llm.prompt.otherPageTitles"))：
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
        \(PromptService.shared.insightQuestionsPrompt)
        \(PromptService.shared.languageInstruction)
        
        要求：
        1. 仅返回 JSON 数组格式，例如: ["问题1", "问题2", "问题3"]
        
        知识库概览：
        \(pageSummaries)
        """
        
        let result = try await llm.generate(prompt: prompt, systemPrompt: "")
        return LLMResponseProcessor.parseJSONArray(result)
    }
}

