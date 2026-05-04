// LLMRefactorService.swift
//
// 作者: Wang Chong
// 功能说明: LLM 重构服务 (Architect & Dev 视角：解耦重构逻辑)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

/// LLM 重构服务 (Architect & Dev 视角：解耦重构逻辑)
final class LLMRefactorService: Sendable {
    private let client: LLMClient
    private let model: String

    init(client: LLMClient, model: String) {
        self.client = client
        self.model = model
    }

    /// 扫描文本以发现潜在的内部链接建议
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        let prompt = """
        \(PromptService.shared.potentialLinksPrompt)

        现有页面标题列表：
        \(existingTitles.joined(separator: ", "))

        待分析文本：
        \"\"\"
        \(content)
        \"\"\"
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
              let text = message["content"] as? String else {
            return []
        }

        return LLMUtils.parseJSONArray(text)
    }

    /// 增量折叠 (Smart Folding)
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.foldingPrompt)

        现有页面内容：
        \(existingContent)

        新资料内容：
        \(newContent)
        """

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 2000
        ]

        let response = try await client.sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return existingContent + "\n\n" + newContent
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 分析一组页面以获取重构建议（合并、拆分、重命名）
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion] {
        let pageData = pages.map { "\($0.title): \($0.content.prefix(150))..." }.joined(separator: "\n---\n")

        let prompt = """
        \(PromptService.shared.refactorPrompt)

        页面简述列表：
        \(pageData)
        """

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3,
            "max_tokens": 1000
        ]

        let response = try await client.sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return []
        }

        return parseRefactorSuggestions(text)
    }

    private func parseRefactorSuggestions(_ text: String) -> [RefactorSuggestion] {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([RefactorSuggestion].self, from: data) else {
            return []
        }
        return array
    }
}

// MARK: - 辅助模型
struct RefactorSuggestion: Codable, Identifiable {
    var id: String { target + type }
    let type: String // merge, split, rename
    let target: String
    let reason: String
    let suggestion: String
}
