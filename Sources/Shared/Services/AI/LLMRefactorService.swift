import Foundation

/// LLM 重构服务 (Architect & Dev 视角：解耦重构逻辑)
final class LLMRefactorService {
    private let client: LLMClient
    private let model: String
    
    init(client: LLMClient, model: String) {
        self.client = client
        self.model = model
    }
    
    /// 扫描文本以发现潜在的内部链接建议
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        let prompt = """
        你是一位专业的知识库架构师。分析给定文本，识别其中提到但未标记为 [[链接]] 的现有页面标题。
        现有页面标题：\(existingTitles.joined(separator: ", "))
        文本：\"\"\"\(content)\"\"\"
        要求：返回 JSON 数组格式，例如: ["标题1", "标题2"]，不要返回任何解释。
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.1,
            "max_tokens": 500
        ]
        
        let response = try await client.sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else { return [] }
        
        return parseJSONArray(text)
    }
    
    /// 增量折叠 (Smart Folding)
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        let prompt = """
        请将以下“新资料”增量式地融合进“现有页面内容”中。
        保持“\(title)”原有结构，去重，插入新知识点。直接返回融合后的 Markdown。
        现有内容：\(existingContent)
        新资料：\(newContent)
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 2000
        ]
        
        let response = try await client.sendRequest(body: requestBody)
        let message = (response["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? (existingContent + "\n\n" + newContent)
    }
    
    private func parseJSONArray(_ text: String) -> [String] {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return array
    }
}
