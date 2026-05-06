// QuizProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了专门用于处理交互式测验数据的处理器（QuizProcessor），负责将非结构化的 AI 响应转换为标准化学习素材。
// 核心逻辑涵盖以下 3 个关键点：
// 1. 结构化解析：支持对复杂 JSON 测验协议的解析，通过内部定义的容器（QuizModelShell）映射题目、选项、标准答案及解析说明。
// 2. 转换渲染：提供将 JSON 结构无损转换为 Markdown 交互格式的功能，并巧妙利用 HTML Details 标签实现答案的隐藏与展示。
// 3. 容错处理：具备强大的 JSON 清洗能力，能够自动剥离 AI 响应中可能包含的 Markdown 代码块声明及冗余的前后文。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Synthesis 并规范化文件头注释
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 专门处理知识测验数据的解析、转换与清洗
enum QuizProcessor {
    
    struct QuizModelShell: Codable {
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

    /// 检查文本是否可以解析为标准的交互式测验模型
    static func canDecodeAsQuizModel(_ text: String) -> Bool {
        let cleaned = cleanJSON(text)
        guard let data = cleaned.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode(QuizModelShell.self, from: data)) != nil
    }

    /// 尝试将 JSON 测验转换为 Markdown 格式
    static func convertJSONToMarkdown(_ text: String) -> String? {
        let cleaned = cleanJSON(text)
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
        
        enum AnyCodable: Codable {
            case int(Int)
            case string(String)
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let i = try? container.decode(Int.self) { self = .int(i) }
                else if let s = try? container.decode(String.self) { self = .string(s) }
                else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not int or string") }
            }
            func encode(to encoder: Encoder) throws {}
            var stringValue: String {
                switch self {
                case .int(let i): return "\(i)"
                case .string(let s): return s
                }
            }
        }

        guard let quiz = try? JSONDecoder().decode(QuizJSON.self, from: data) else { return nil }
        
        var md = "# \(quiz.title ?? Localized.tr("quiz.title"))\n\n"
        for (index, q) in quiz.questions.enumerated() {
            md += "## \(index + 1). \(q.text)\n\n"
            for opt in q.options {
                md += "* \(opt)\n"
            }
            md += "\n<details>\n<summary>\(Localized.tr("quiz.showAnswer"))</summary>\n\n"
            if let ans = q.answer {
                md += "**\(Localized.tr("quiz.correctAnswer"))：** \(ans.stringValue)\n\n"
            }
            if let exp = q.explanation {
                md += "**\(Localized.tr("quiz.explanation"))：** \(exp)\n"
            }
            md += "\n</details>\n\n"
        }
        
        return md
    }

    /// 清洗 AI 返回的 JSON 字符串
    static func cleanJSON(_ text: String) -> String {
        return text.replacingOccurrences(of: "```json", with: "")
                   .replacingOccurrences(of: "```", with: "")
                   .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
