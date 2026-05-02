import Foundation

/// AI 知识综合服务 (L1 领域层)
/// 负责具体的业务 Prompt 编排与结果解析，解耦 LLMService。
@MainActor
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
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a Mermaid mindmap expert. Only output mindmap code starting with 'mindmap'. Never use '-' for bullets. Use strictly 2 spaces for indentation. Do not use colons or parentheses inside the text.")
        
        var cleaned = result
        // 严格提取 mindmap 代码块，忽略前面的废话
        if let range = cleaned.range(of: "mindmap") {
            cleaned = String(cleaned[range.lowerBound...])
        }
        
        cleaned = cleaned.replacingOccurrences(of: "```mermaid", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除行首的 - 和 * (AI 经常习惯性带上列表符号)
        let lines = cleaned.components(separatedBy: .newlines)
        let processedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var fixed = line
            if trimmed.hasPrefix("- ") {
                fixed = fixed.replacingOccurrences(of: "- ", with: "  ")
            } else if trimmed.hasPrefix("* ") {
                fixed = fixed.replacingOccurrences(of: "* ", with: "  ")
            }
            // 简单的非法字符替换，防止解析崩溃
            if fixed.contains(":") && !fixed.contains("mindmap") {
                fixed = fixed.replacingOccurrences(of: ":", with: "：")
            }
            return fixed
        }
        cleaned = processedLines.joined(separator: "\n")
        
        return "```mermaid\n\(cleaned)\n```"
    }
    
    /// 提取行动项
    func extractActions(content: String) async throws -> String {
        let prompt = PromptService.shared.actionPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "")
    }
    
    /// 生成演示文稿大纲 (Markdown Slides)
    func generatePresentation(content: String) async throws -> String {
        let prompt = PromptService.shared.slidesPrompt + "\n\n内容：\n\(content)"
        return try await llm.generate(prompt: prompt, systemPrompt: "You are a presentation expert. Use Markdown. Use '# ' for Title slide, '## ' for new slides. Use bullet points.")
    }

    /// 将 Markdown 转换为 PPTX 文件
    func convertToPPTX(markdown: String, title: String) async throws -> URL {
        #if os(macOS)
        return try await PPTXGenerator.shared.generate(markdown: markdown, title: title)
        #else
        // iOS 平台目前不支持原生生成 PPTX (受限于系统权限和缺少 Zip 库)
        // 建议导出为 PDF 或拷贝内容
        throw NSError(domain: "PPTXConversion", code: 405, userInfo: [NSLocalizedDescriptionKey: "iOS 平台暂不支持原生导出 PPTX，请尝试导出为 PDF。"])
        #endif
    }
    
    /// 生成测验题
    func generateQuiz(content: String) async throws -> String {
        let prompt = PromptService.shared.quizPrompt + "\n\n内容：\n\(content)"
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a quiz generator. Strictly follow the user's requested format. If you output JSON, ensure it follows the standard {title, questions: [{text, options, answer, explanation}]} structure.")
        
        // 尝试解析 JSON 并格式化为 Markdown
        if let formatted = tryFormatJSONQuiz(result) {
            return formatted
        }
        
        return result
    }

    private func tryFormatJSONQuiz(_ text: String) -> String? {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        
        struct QuizJSON: Codable {
            let title: String?
            let questions: [QuestionJSON]
        }
        struct QuestionJSON: Codable {
            let id: Int?
            let text: String
            let options: [String]
            let answer: AnyCodable?
            let explanation: String?
        }
        
        // 简单的 AnyCodable 处理数字或字符串索引
        enum AnyCodable: Codable {
            case int(Int)
            case string(String)
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let i = try? container.decode(Int.self) { self = .int(i) }
                else if let s = try? container.decode(String.self) { self = .string(s) }
                else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not int or string") }
            }
            func encode(to encoder: Encoder) throws { /* unused */ }
            var stringValue: String {
                switch self {
                case .int(let i): return "\(i)"
                case .string(let s): return s
                }
            }
        }

        guard let quiz = try? JSONDecoder().decode(QuizJSON.self, from: data) else { return nil }
        
        var md = "# \(quiz.title ?? "知识测验")\n\n"
        for (index, q) in quiz.questions.enumerated() {
            md += "## \(index + 1). \(q.text)\n\n"
            for opt in q.options {
                md += "* \(opt)\n"
            }
            md += "\n<details>\n<summary>查看答案与解析</summary>\n\n"
            if let ans = q.answer {
                md += "**正确答案：** \(ans.stringValue)\n\n"
            }
            if let exp = q.explanation {
                md += "**解析：** \(exp)\n"
            }
            md += "\n</details>\n\n"
        }
        
        return md
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
