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
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a Mermaid mindmap expert. Output ONLY valid mindmap code. Start strictly with 'mindmap'. Use root((Title)) for root node. Indent with 2 spaces. Do not use colons or parentheses in node text unless quoted.")
        
        var cleaned = result
        
        // 1. 正则精准提取 mindmap 部分，处理可能的 markdown 围栏或前后文
        if let range = cleaned.range(of: #"(?s)mindmap.*"#, options: .regularExpression) {
            cleaned = String(cleaned[range])
        }
        
        // 2. 移除常见的 markdown 标记
        cleaned = cleaned.replacingOccurrences(of: "```mermaid", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 3. 逐行修复非法语法
        let lines = cleaned.components(separatedBy: .newlines)
        let processedLines = lines.map { line -> String in
            var fixed = line
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 忽略空行
            if trimmed.isEmpty { return "" }
            
            // 处理 AI 习惯性添加的列表符号（如 - 或 *）
            if trimmed.hasPrefix("- ") {
                fixed = line.replacingOccurrences(of: "- ", with: "  ")
            } else if trimmed.hasPrefix("* ") {
                fixed = line.replacingOccurrences(of: "* ", with: "  ")
            }
            
            // 针对 Mermaid Mindmap 的特殊转义
            // 如果行内包含括号且不是 mindmap 关键字或 root((...)) 格式，则将括号替换为全角
            if !fixed.contains("mindmap") && !fixed.contains("((") {
                if fixed.contains("(") || fixed.contains(")") {
                    fixed = fixed.replacingOccurrences(of: "(", with: "（").replacingOccurrences(of: ")", with: "）")
                }
            }
            
            // 冒号替换为全角，防止解析错误
            if fixed.contains(":") && !fixed.contains("mindmap") {
                fixed = fixed.replacingOccurrences(of: ":", with: "：")
            }
            
            return fixed
        }
        
        cleaned = processedLines.filter { !$0.isEmpty }.joined(separator: "\n")
        
        // 如果清理后不以 mindmap 开头，强行修补
        if !cleaned.lowercased().hasPrefix("mindmap") {
            cleaned = "mindmap\n  " + cleaned
        }
        
        return cleaned
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
        return try await WebViewExportService.shared.exportToPPTX(markdown: markdown, fileName: title)
    }
    
    /// 生成测验题
    func generateQuiz(content: String) async throws -> String {
        let prompt = PromptService.shared.quizPrompt + "\n\n内容：\n\(content)"
        let jsonFormat = """
        {"title":"测验标题","questions":[{"id":0,"text":"问题？","options":["A选项","B选项","C选项","D选项"],"answer":0,"explanation":"解释"}]}
        """
        let result = try await llm.generate(prompt: prompt, systemPrompt: "You are a quiz generator. Output ONLY valid JSON (no markdown fences) in this exact format: \(jsonFormat). answer is 0-based index (0=A,1=B,2=C,3=D). explanation tells why the answer is correct. Do NOT wrap in ```json```.")

        // 尝试直接解析为 QuizModel 兼容 JSON（优先交互式测验）
        if canDecodeAsQuizModel(result) {
            return result
        }

        // 兜底：尝试解析其他 JSON 格式并转换为 Markdown
        if let formatted = tryFormatJSONQuiz(result) {
            return formatted
        }

        return result
    }

    private func canDecodeAsQuizModel(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode(QuizModelShell.self, from: data)) != nil
    }

    private struct QuizModelShell: Codable {
        let title: String
        let questions: [QuestionShell]
        struct QuestionShell: Codable {
            let id: Int?
            let text: String
            let options: [String]
            let answer: Int
            let explanation: String?
        }
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
        return try await llm.generate(prompt: prompt, systemPrompt: "You are a report writer. First line MUST be '# <title>' summarizing the report topic. Use Markdown headings for sections.")
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
        \(PromptService.shared.insightQuestionsPrompt)
        
        要求：
        1. 仅返回 JSON 数组格式，例如: ["问题1", "问题2", "问题3"]
        
        知识库概览：
        \(pageSummaries)
        """
        
        let result = try await llm.generate(prompt: prompt, systemPrompt: "")
        return parseJSONArray(result)
    }
    
    private func parseJSONArray(_ text: String) -> [String] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try direct parse first
        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        
        // Try to find [ ... ] block using regex if direct parse failed
        let pattern = "\\[[\\s\\S]*\\]"
        if let range = cleaned.range(of: pattern, options: .regularExpression) {
            let jsonPart = String(cleaned[range])
            if let data = jsonPart.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                return array
            }
        }
        
        return []
    }
}

// 补充单例支持
extension LLMService {
    static let shared = LLMService()
}
