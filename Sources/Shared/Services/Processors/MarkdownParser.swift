import Foundation

// MARK: - Markdown Parser
/// Pure parsing layer for Markdown content. Returns structured block representations.
/// Rendering is handled separately by MarkdownRendererView.
final class MarkdownParser {

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
    }

    // MARK: - Inline Types
    enum InlineType {
        case text, bold, italic, code, wikilink, emoji
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
        if line.hasPrefix("# ") {
            return .heading(text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces), level: 1)
        } else if line.hasPrefix("## ") {
            return .heading(text: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), level: 2)
        } else if line.hasPrefix("### ") {
            return .heading(text: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces), level: 3)
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
        var remaining = text

        while !remaining.isEmpty {
            // Wikilink [[...]]
            if let range = remaining.range(of: "\\[\\[([^\\]]+)\\]\\]", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    segments.append(InlineSegment(type: .text, content: before))
                }
                let linkContent = remaining[range].dropFirst(2).dropLast(2)
                let linkTitle = String(linkContent.split(separator: "|").first ?? Substring(linkContent))
                segments.append(InlineSegment(type: .wikilink, content: linkTitle.trimmingCharacters(in: .whitespaces)))
                remaining = String(remaining[range.upperBound...])
            }
            // Bold **...**
            else if let range = remaining.range(of: "\\*\\*([^*]+)\\*\\*", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    segments.append(InlineSegment(type: .text, content: before))
                }
                let boldContent = remaining[range].dropFirst(2).dropLast(2)
                segments.append(InlineSegment(type: .bold, content: String(boldContent)))
                remaining = String(remaining[range.upperBound...])
            }
            // Code `...`
            else if let range = remaining.range(of: "`([^`]+)`", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    segments.append(InlineSegment(type: .text, content: before))
                }
                let codeContent = remaining[range].dropFirst().dropLast()
                segments.append(InlineSegment(type: .code, content: String(codeContent)))
                remaining = String(remaining[range.upperBound...])
            }
            // Italic *...*
            else if let range = remaining.range(of: "\\*([^*]+)\\*", options: .regularExpression) {
                let before = String(remaining[remaining.startIndex..<range.lowerBound])
                if !before.isEmpty {
                    segments.append(InlineSegment(type: .text, content: before))
                }
                let italicContent = remaining[range].dropFirst().dropLast()
                segments.append(InlineSegment(type: .italic, content: String(italicContent)))
                remaining = String(remaining[range.upperBound...])
            }
            else {
                segments.append(InlineSegment(type: .text, content: remaining))
                remaining = ""
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
