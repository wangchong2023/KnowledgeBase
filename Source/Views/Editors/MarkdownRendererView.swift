import SwiftUI

// MARK: - Markdown Renderer View
/// Renders structured Markdown blocks using MarkdownParser.
/// Parsing logic is extracted to MarkdownParser service for reuse.
struct MarkdownRendererView: View {
    let content: String
    let onLinkTap: (String) -> Void

    private let parser = MarkdownParser()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let blocks = parser.parse(content)
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Renderer
    @ViewBuilder
    private func renderBlock(_ block: MarkdownParser.BlockType) -> some View {
        switch block {
        case .heading(let text, let level):
            renderHeading(text: text, level: level)
        case .paragraph(let text):
            renderParagraph(text: text)
        case .bulletList(let items, let indent):
            renderBulletList(items: items, indent: indent)
        case .blockquote(let text):
            renderBlockquote(text: text)
        case .codeBlock(let code, let language):
            renderCodeBlock(code: code, language: language)
        case .table(let headers, let rows):
            renderTable(headers: headers, rows: rows)
        case .horizontalRule:
            renderHorizontalRule()
        case .taskList(let items):
            renderTaskList(items: items)
        }
    }

    // MARK: - Render Heading
    @ViewBuilder
    private func renderHeading(text: String, level: Int) -> some View {
        let size: CGFloat = level == 1 ? 24 : level == 2 ? 20 : 17
        renderInlineContent(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(.wikiText)
            .padding(.top, level == 1 ? 8 : 4)
            .padding(.bottom, 2)
    }

    // MARK: - Render Paragraph
    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineContent(text)
            .foregroundStyle(.wikiText)
            .lineSpacing(4)
    }

    // MARK: - Render Bullet List
    @ViewBuilder
    private func renderBulletList(items: [String], indent: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.wikiAccent)
                        .frame(width: 16)
                    renderInlineContent(item)
                        .foregroundStyle(.wikiText)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(indent) * 16)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Render Blockquote
    @ViewBuilder
    private func renderBlockquote(text: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: WikiUI.hairlineRadius)
                .fill(Color.wikiAccent.opacity(0.5))
                .frame(width: 3)
                .padding(.trailing, 10)

            renderInlineContent(text)
                .font(.body.italic())
                .foregroundStyle(.wikiSecondary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Render Code Block
    @ViewBuilder
    private func renderCodeBlock(code: String, language: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                Text(language)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.wikiSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.wikiText.opacity(0.9))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.wikiCard.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }

    // MARK: - Render Table
    @ViewBuilder
    private func renderTable(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                    renderInlineContent(cell)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.wikiAccent.opacity(0.1))

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        renderInlineContent(cell)
                            .font(.subheadline)
                            .foregroundStyle(.wikiText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                .background(rowIdx % 2 == 0 ? Color.clear : Color.wikiCard.opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }

    // MARK: - Render Horizontal Rule
    @ViewBuilder
    private func renderHorizontalRule() -> some View {
        Divider()
            .background(Color.wikiBorder)
            .padding(.vertical, 8)
    }

    // MARK: - Render Task List
    @ViewBuilder
    private func renderTaskList(items: [(text: String, checked: Bool)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                        .font(.body)
                        .foregroundStyle(item.checked ? .green : .wikiSecondary)
                    renderInlineContent(item.text)
                        .foregroundStyle(item.checked ? .wikiSecondary : .wikiText)
                        .strikethrough(item.checked)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Content Renderer
    @ViewBuilder
    private func renderInlineContent(_ text: String) -> some View {
        let segments = parser.parseInlineSegments(text)
        
        Text(buildAttributedString(from: segments))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func buildAttributedString(from segments: [MarkdownParser.InlineSegment]) -> AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            var container = AttributedString(segment.content)
            
            switch segment.type {
            case .text:
                container.font = .body
            case .bold:
                container.font = .body.weight(.bold)
            case .italic:
                container.font = .body.italic()
            case .code:
                container.font = .system(.caption, design: .monospaced)
                container.backgroundColor = Color.wikiAccent.opacity(0.15)
                container.foregroundColor = .wikiText
            case .wikilink:
                container.font = .body.weight(.medium)
                container.foregroundColor = .wikiAccent
                container.underlineStyle = .single
                // 我们在 Text 上无法直接捕获这个特定属性的点击，
                // 但我们可以通过转换整个 Text 为 Link 或使用自定义属性。
                // 暂时使用标准 link 属性，由外部 onLinkTap 处理或通过自定义 URL 协议。
                if let encoded = segment.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    container.link = URL(string: "wikilink://\(encoded)")
                }
            case .emoji:
                container.font = .body
            }
            
            result.append(container)
        }
        
        return result
    }
}
