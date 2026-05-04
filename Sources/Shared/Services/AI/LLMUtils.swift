// LLMUtils.swift
//
// 作者: Wang Chong
// 功能说明: Shared LLM utility functions.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

/// Shared LLM utility functions.
enum LLMUtils {
    /// Parse a JSON string array from LLM output, stripping markdown fences if present.
    static func parseJSONArray(_ text: String) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }

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
