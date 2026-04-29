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
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Code block
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: language))
                continue
            }

            // Heading
            if trimmed.hasPrefix("# ") {
                blocks.append(.heading(text: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces), level: 1))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.heading(text: String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces), level: 2))
            } else if trimmed.hasPrefix("### ") {
                blocks.append(.heading(text: String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces), level: 3))
            }
            // Horizontal rule
            else if trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                blocks.append(.horizontalRule)
            }
            // Task list
            else if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("* [ ] ") || trimmed.hasPrefix("* [x] ") {
                var items: [(text: String, checked: Bool)] = []
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
                blocks.append(.taskList(items: items))
                continue
            }
            // Bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count {
                    let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") {
                        items.append(String(listLine.dropFirst(2)))
                    } else {
                        break
                    }
                    i += 1
                }
                blocks.append(.bulletList(items: items, indent: 0))
                continue
            }
            // Numbered list
            else if trimmed.count >= 3 && trimmed.first?.isNumber == true && trimmed.dropFirst().first == "." && trimmed.dropFirst(2).first == " " {
                var items: [String] = []
                while i < lines.count {
                    let numLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if numLine.count >= 3 && numLine.first?.isNumber == true && numLine.dropFirst().first == "." {
                        let dotIndex = numLine.firstIndex(of: ".")!
                        items.append(String(numLine[numLine.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces))
                    } else {
                        break
                    }
                    i += 1
                }
                blocks.append(.bulletList(items: items, indent: 0))
                continue
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                blocks.append(.blockquote(text: String(trimmed.dropFirst(2))))
            }
            // Table
            else if isTableLine(trimmed) {
                var tableLines: [String] = []
                while i < lines.count && isTableLine(lines[i].trimmingCharacters(in: .whitespaces)) {
                    tableLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                    i += 1
                }

                let dataLines = tableLines.filter { !$0.hasPrefix("|-") && !$0.hasPrefix("| -") }
                if !dataLines.isEmpty {
                    let headers = parseTableCells(dataLines[0])
                    var rows: [[String]] = []
                    for lineIdx in 1..<dataLines.count {
                        rows.append(parseTableCells(dataLines[lineIdx]))
                    }
                    blocks.append(.table(headers: headers, rows: rows))
                }
                continue
            }
            // Regular paragraph
            else {
                blocks.append(.paragraph(text: trimmed))
            }

            i += 1
        }

        return blocks
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
