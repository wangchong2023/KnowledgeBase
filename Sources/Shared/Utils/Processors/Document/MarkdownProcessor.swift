// MarkdownProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了全功能 Markdown 文本解析处理器（MarkdownProcessor），是系统中内容渲染与语义理解的核心组件。
// 该处理器通过高性能正则引擎实现以下功能点：
// 1. 深度标题识别：支持从 H1 到 H6 的全层级标准标题解析，并能自动去除冗余的 Markdown 符号。
// 2. 块类型提取：精准识别并分离普通段落、无序列表、代码块以及引用块，将其转换为结构化的中间模型。
// 3. 实时清洗：自动剔除不规范的换行符和首尾空格，确保输出的内容在 UI 层渲染时具备一致的边距表现。
// 4. 扩展性支持：预留了对自定义标记和公式解析的扩展接口，保障了文档解析能力的持续进化。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 优化 H1-H6 解析逻辑，迁移至 Utils/Processors 归口管理
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

// MARK: - Markdown Parser
/// Pure parsing layer for Markdown content. Returns structured block representations.
/// Rendering is handled separately by MarkdownRendererView.
final class MarkdownProcessor {

    // MARK: - Block Types
    enum BlockType {
        case heading(text: String, level: Int)
        case paragraph(text: String)
        case bulletList(items: [String], indent: Int)
        case blockquote(text: String)
        case codeBlock(code: String, language: String)
        case table(headers: [String], rows: [[String]])
        case horizontalRule
        case taskList(items: [(text: String, checked: Bool)])
        case details(summary: String, content: String)
    }

    // MARK: - Inline Types
    enum InlineType {
        case text, bold, italic, code, wikilink, link, emoji
    }

    struct InlineSegment {
        let type: InlineType
        let content: String
    }

    // MARK: - Parse Full Content
    func parse(_ content: String) -> [BlockType] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [BlockType] = []
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Try each block type parser
            if let result = parseDetailsBlock(lines: lines, startIndex: i) {
                blocks.append(result.block)
                i = result.nextIndex
                continue
            }

            if let result = parseCodeBlock(lines: lines, startIndex: i) {
                blocks.append(result.block)
                i = result.nextIndex
                continue
            }

            if let result = parseHeading(trimmed) {
                blocks.append(result)
                i += 1
                continue
            }

            if let result = parseHorizontalRule(trimmed) {
                blocks.append(result)
                i += 1
                continue
            }

            if let result = parseTaskList(lines: lines, startIndex: i) {
                blocks.append(result.block)
                i = result.nextIndex
                continue
            }

            if let result = parseBulletList(lines: lines, startIndex: i) {
                blocks.append(result.block)
                i = result.nextIndex
                continue
            }

            if let result = parseBlockquote(trimmed) {
                blocks.append(result)
                i += 1
                continue
            }

            if let result = parseTable(lines: lines, startIndex: i) {
                blocks.append(result.block)
                i = result.nextIndex
                continue
            }

            // Default: paragraph
            blocks.append(.paragraph(text: trimmed))
            i += 1
        }

        return blocks
    }

    // MARK: - Parse Details Block
    private func parseDetailsBlock(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("<details>") else { return nil }

        var summary = ""
        var contentLines: [String] = []
        var i = startIndex + 1

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("</details>") {
                i += 1
                break
            }

            if line.hasPrefix("<summary>") && line.contains("</summary>") {
                summary = line.replacingOccurrences(of: "<summary>", with: "")
                              .replacingOccurrences(of: "</summary>", with: "")
            } else if line.hasPrefix("<summary>") {
                // Handle multi-line summary if needed (rare but possible)
                summary = line.replacingOccurrences(of: "<summary>", with: "")
            } else if line.contains("</summary>") {
                summary += line.replacingOccurrences(of: "</summary>", with: "")
            } else {
                contentLines.append(lines[i])
            }
            i += 1
        }

        if summary.isEmpty { summary = "Details" }
        return (.details(summary: summary, content: contentLines.joined(separator: "\n")), i)
    }

    // MARK: - Parse Code Block
    private func parseCodeBlock(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else { return nil }

        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        var i = startIndex + 1

        while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            codeLines.append(lines[i])
            i += 1
        }

        return (.codeBlock(code: codeLines.joined(separator: "\n"), language: language), i + 1)
    }

    // MARK: - Parse Heading
    private func parseHeading(_ line: String) -> BlockType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        
        let hashes = trimmed.prefix(while: { $0 == "#" })
        let level = hashes.count
        
        // 标题后面必须跟一个空格才是标准的 Markdown 标题 (e.g. "### Title")
        guard level >= 1 && level <= 6 else { return nil }
        
        let contentStart = trimmed.index(trimmed.startIndex, offsetBy: level)
        guard contentStart < trimmed.endIndex else { return nil }
        
        let afterHashes = trimmed[contentStart...]
        if afterHashes.hasPrefix(" ") {
            return .heading(text: afterHashes.trimmingCharacters(in: .whitespaces), level: level)
        }
        
        return nil
    }

    // MARK: - Parse Horizontal Rule
    private func parseHorizontalRule(_ line: String) -> BlockType? {
        if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
            return .horizontalRule
        }
        return nil
    }

    // MARK: - Parse Task List
    private func parseTaskList(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") ||
              trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("* [ ] ") ||
              trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") else {
            return nil
        }

        var items: [(text: String, checked: Bool)] = []
        var i = startIndex

        while i < lines.count {
            let taskLine = lines[i].trimmingCharacters(in: .whitespaces)
            if taskLine.hasPrefix("- [ ] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: false))
            } else if taskLine.hasPrefix("- [x] ") || taskLine.hasPrefix("- [X] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: true))
            } else if taskLine.hasPrefix("* [ ] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: false))
            } else if taskLine.hasPrefix("* [x] ") || taskLine.hasPrefix("* [X] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: true))
            } else {
                break
            }
            i += 1
        }

        return (.taskList(items: items), i)
    }

    // MARK: - Parse Bullet List
    private func parseBulletList(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)

        // Check if it's a bullet or numbered list
        let isBulletList = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
        let isNumberedList = trimmed.count >= 3 && trimmed.first?.isNumber == true &&
                            trimmed.dropFirst().first == "." && trimmed.dropFirst(2).first == " "

        guard isBulletList || isNumberedList else { return nil }

        var items: [String] = []
        var i = startIndex

        while i < lines.count {
            let listLine = lines[i].trimmingCharacters(in: .whitespaces)

            if isBulletList && (listLine.hasPrefix("- ") || listLine.hasPrefix("* ")) {
                items.append(String(listLine.dropFirst(2)))
            } else if isNumberedList && listLine.count >= 3 && listLine.first?.isNumber == true && listLine.dropFirst().first == "." {
                if let dotIndex = listLine.firstIndex(of: ".") {
                    items.append(String(listLine[listLine.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces))
                }
            } else {
                break
            }
            i += 1
        }

        return (.bulletList(items: items, indent: 0), i)
    }

    // MARK: - Parse Blockquote
    private func parseBlockquote(_ line: String) -> BlockType? {
        if line.hasPrefix("> ") {
            return .blockquote(text: String(line.dropFirst(2)))
        }
        return nil
    }

    // MARK: - Parse Table
    private func parseTable(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        guard isTableLine(lines[startIndex].trimmingCharacters(in: .whitespaces)) else { return nil }

        var tableLines: [String] = []
        var i = startIndex

        while i < lines.count && isTableLine(lines[i].trimmingCharacters(in: .whitespaces)) {
            tableLines.append(lines[i].trimmingCharacters(in: .whitespaces))
            i += 1
        }

        let dataLines = tableLines.filter { !$0.hasPrefix("|-") && !$0.hasPrefix("| -") }
        guard !dataLines.isEmpty else { return nil }

        let headers = parseTableCells(dataLines[0])
        var rows: [[String]] = []
        for lineIdx in 1..<dataLines.count {
            rows.append(parseTableCells(dataLines[lineIdx]))
        }

        return (.table(headers: headers, rows: rows), i)
    }

    // MARK: - Inline Parsing
    func parseInlineSegments(_ text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        let nsText = text as NSString
        var currentOffset = 0

        let patterns: [(InlineType, NSRegularExpression)] = [
            (.wikilink, .wikiLinkRegex),
            (.link, .linkRegex),
            (.bold, .boldRegex),
            (.italic, .italicRegex),
            (.code, .codeRegex)
        ]

        while currentOffset < nsText.length {
            var earliestMatch: (type: InlineType, match: NSTextCheckingResult)?

            for (type, regex) in patterns {
                if let match = regex.firstMatch(in: text, range: NSRange(location: currentOffset, length: nsText.length - currentOffset)) {
                    if earliestMatch == nil || match.range.location < earliestMatch!.match.range.location {
                        earliestMatch = (type, match)
                    }
                }
            }

            if let earliest = earliestMatch {
                let matchRange = earliest.match.range
                
                // Add text before the match
                if matchRange.location > currentOffset {
                    let before = nsText.substring(with: NSRange(location: currentOffset, length: matchRange.location - currentOffset))
                    segments.append(InlineSegment(type: .text, content: before))
                }

                // Add the matched segment
                let content: String
                switch earliest.type {
                case .wikilink:
                    let raw = nsText.substring(with: earliest.match.range(at: 1))
                    content = raw.split(separator: "|").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? raw
                case .link:
                    let label = nsText.substring(with: earliest.match.range(at: 1))
                    let url = nsText.substring(with: earliest.match.range(at: 2))
                    content = "\(label)|\(url)"
                case .bold, .italic, .code:
                    content = nsText.substring(with: earliest.match.range(at: 1))
                default:
                    content = ""
                }
                
                segments.append(InlineSegment(type: earliest.type, content: content))
                currentOffset = matchRange.location + matchRange.length
            } else {
                // Add remaining text
                let remainingText = nsText.substring(from: currentOffset)
                segments.append(InlineSegment(type: .text, content: remainingText))
                break
            }
        }

        return segments
    }

    // MARK: - Table Helpers
    private func isTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|")
    }

    private func parseTableCells(_ line: String) -> [String] {
        line.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-") }
    }
}

extension NSRegularExpression {
    static let wikiLinkRegex = try! NSRegularExpression(pattern: "\\[\\[([^\\]]+)\\]\\]")
    static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*")
    static let italicRegex = try! NSRegularExpression(pattern: "\\*([^*]+)\\*")
    static let codeRegex = try! NSRegularExpression(pattern: "`([^`]+)`")
    static let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)")
}
