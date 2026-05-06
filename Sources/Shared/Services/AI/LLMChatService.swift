// LLMChatService.swift
//
// 作者: Wang Chong
// 功能说明: LLM 对话服务 — 处理 LLM API 请求构建、发送和响应解析
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// LLM 对话服务 — 处理 LLM API 请求构建、发送和响应解析
final class LLMChatService: Sendable {
    private let client: LLMClient
    private let model: String

    init(client: LLMClient, model: String) {
        self.client = client
        self.model = model
    }

    // MARK: - 请求体构造

    private func buildChatMessages(systemPrompt: String, query: String, history: [ChatMessage]) -> [[String: Any]] {
        let fullSystemPrompt = systemPrompt + PromptService.shared.languageInstruction
        var messages: [[String: Any]] = [["role": "system", "content": fullSystemPrompt]]
        for msg in history {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        messages.append(["role": "user", "content": query])
        return messages
    }

    private func makeChatRequestBody(systemPrompt: String, query: String, history: [ChatMessage]) -> [String: Any] {
        [
            "model": model,
            "messages": buildChatMessages(systemPrompt: systemPrompt, query: query, history: history),
            "temperature": 0.7,
            "max_tokens": 2000
        ]
    }

    private func makeStreamingRequestBody(systemPrompt: String, query: String, history: [ChatMessage]) -> [String: Any] {
        [
            "model": model,
            "messages": buildChatMessages(systemPrompt: systemPrompt, query: query, history: history),
            "temperature": 0.7,
            "max_tokens": 2000,
            "stream": true
        ]
    }

    // MARK: - 非流式对话
    
    /// 执行非流式对话，内部构造请求体以确保线程安全
    func chat(systemPrompt: String, query: String, history: [ChatMessage]) async throws -> String {
        let requestBody = makeChatRequestBody(systemPrompt: systemPrompt, query: query, history: history)
        let response = try await client.sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "LLMChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        return content
    }

    // MARK: - 流式对话

    /// 执行流式对话，内部构造请求体以确保线程安全
    func streamChat(systemPrompt: String, query: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream(String.self) { continuation in
            Task {
                do {
                    let requestBody = makeStreamingRequestBody(systemPrompt: systemPrompt, query: query, history: history)
                    let streamResult = try await client.sendStreamingRequest(body: requestBody)
                    for try await line in streamResult.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        if trimmed.hasPrefix("data: ") {
                            let dataString = String(trimmed.dropFirst(6))
                            if dataString == "[DONE]" { break }
                            guard let data = dataString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let delta = choices.first?["delta"] as? [String: Any],
                                  let content = delta["content"] as? String else {
                                continue
                            }
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Utility

    func extractWikiLinks(from text: String) -> [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }
}
