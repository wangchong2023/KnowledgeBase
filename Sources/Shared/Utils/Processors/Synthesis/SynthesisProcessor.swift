// SynthesisProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了结构化内容合成处理器（SynthesisProcessor），专门负责对多媒体和图表内容进行标准化转换与语法修复。
// 该处理器的核心流水线包括：
// 1. Mermaid 语法加固：自动识别并转换 Mermaid 图表中的非法字符（如半角括号、冒号），防止渲染引擎解析崩溃。
// 2. 标题层级感应：精准识别 Markdown 顶层标题，为合成后的文档提供动态标题生成依据。
// 3. 容错式代码补全：针对非标准的代码块输出，能够自动补全 Mermaid 声明头（如 mindmap, graph），确保内容的视觉呈现稳定性。
// 4. 文本深度净化：移除冗余的 AI 生成标记，提取纯净的功能性代码段。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Synthesis 并整合多媒体格式化逻辑
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

/// 针对知识合成（思维导图、演示文稿、知识测验、深度报告、信息图）的通用处理工具
enum SynthesisProcessor {
    
    /// 格式化 Mermaid 代码块
    /// - Parameters:
    ///   - text: 包含 Mermaid 代码的原始文本
    ///   - fallbackPrefix: 当无法自动识别图表类型时的默认前缀
    /// - Returns: 标准化的 Mermaid 代码块
    static func formatMermaid(_ text: String, fallbackPrefix: String) -> String {
        var cleaned = text.replacingOccurrences(of: "```mermaid", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 提取标题 (如果有 # 标题)
        var title: String? = nil
        if cleaned.hasPrefix("# ") {
            if let firstLineEnd = cleaned.firstIndex(of: "\n") {
                title = String(cleaned[..<firstLineEnd])
                cleaned = String(cleaned[cleaned.index(after: firstLineEnd)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. 尝试提取核心代码块 (更加灵活的正则，支持不带方向的 graph)
        let patterns = ["mindmap.*", "graph.*", "pie.*", "timeline.*", "sequenceDiagram.*", "gantt.*"]
        var mermaidCode: String = cleaned
        var foundMatch = false
        
        for pattern in patterns {
            if let range = cleaned.range(of: "(?s)\(pattern)", options: .regularExpression) {
                mermaidCode = String(cleaned[range])
                foundMatch = true
                break
            }
        }
        
        // 3. 如果完全没有匹配且不包含关键字，则尝试加上前缀
        // 4. 特殊处理：如果只有 graph 但没有方向，则补全方向
        if !foundMatch {
            mermaidCode = "\(fallbackPrefix)\n  " + mermaidCode.replacingOccurrences(of: "\n", with: "\n  ")
        } else if mermaidCode.trimmingCharacters(in: .whitespaces) == "graph" {
            mermaidCode = "graph TD"
        } else if mermaidCode.hasPrefix("graph") && !mermaidCode.contains("TD") && !mermaidCode.contains("LR") && !mermaidCode.contains("TB") && !mermaidCode.contains("BT") {
            // 如果只有 graph 但紧接着没写方向，补上 TD
            mermaidCode = mermaidCode.replacingOccurrences(of: "graph", with: "graph TD", options: .anchored)
        }
        
        // 对最终确定的 Mermaid 代码进行语法纠错加固
        mermaidCode = sanitizeMermaidSyntax(mermaidCode)
        
        if let title = title {
            return "\(title)\n\n\(mermaidCode)"
        } else {
            return mermaidCode
        }
    }
    
    /// 对 Mermaid 进行语法纠错加固 (处理节点文本中的非法字符)
    private static func sanitizeMermaidSyntax(_ code: String) -> String {
        var lines = code.components(separatedBy: .newlines)
        for i in 0..<lines.count {
            var line = lines[i]
            // 处理节点文本中的特殊字符 (:, (, ), [, ])
            if let start = line.firstIndex(of: "[") ?? line.firstIndex(of: "("),
               let end = line.lastIndex(of: "]") ?? line.lastIndex(of: ")") {
                let range = start...end
                var content = String(line[range])
                content = content.replacingOccurrences(of: ":", with: "：")
                                 .replacingOccurrences(of: "((", with: "（（")
                                 .replacingOccurrences(of: "))", with: "））")
                line.replaceSubrange(range, with: content)
            }
            lines[i] = line
        }
        return lines.joined(separator: "\n")
    }
    
    /// 从文本内容中提取第一个 H1 级别的标题
    static func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 寻找第一个非空的 Markdown 标题行
        if let firstLine = lines.first(where: { !$0.isEmpty && $0.hasPrefix("# ") }) {
            return firstLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
}
