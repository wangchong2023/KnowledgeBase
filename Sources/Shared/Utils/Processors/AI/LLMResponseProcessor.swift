// LLMResponseProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了大语言模型响应处理器（LLMResponseProcessor），旨在对 AI 返回的原始数据流进行深度的清洗与结构化。
// 该组件主要承担以下核心任务：
// 1. 结构化 JSON 提取：专门针对 AI 返回的 JSON 列表进行解析，支持自动过滤非 JSON 字符，将其转换为强类型的 Swift 模型数组。
// 2. Markdown 语法净化：自动识别并剥离响应中的代码块声明（如 ```json 等），确保数据解析引擎能够获得纯净的 payload。
// 3. 容错性降级处理：在解析失败时提供预定义的兜底逻辑，并记录详细的错误上下文，保障业务流程的连续性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/AI 并完善数据清洗逻辑说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// Shared LLM utility functions.
enum LLMResponseProcessor {
    /// Parse a JSON string array from LLM output, stripping markdown fences if present.
    static func parseJSONArray(_ text: String) -> [String] {
        let cleaned = stripMarkdown(text)
        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }
        return []
    }

    static func parseSmartIngest(_ text: String) -> SmartIngestResult? {
        let cleaned = stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SmartIngestResult.self, from: data)
    }

    static func parseRefactorSuggestions(_ text: String) -> [RefactorSuggestion] {
        let cleaned = stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([RefactorSuggestion].self, from: data)) ?? []
    }

    private static func stripMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
