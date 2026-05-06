// MarkdownRendererView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了基于文本块解析的高级 Markdown 渲染组件（MarkdownRendererView），负责将抽象的 Markdown 语法树转化为原生 SwiftUI 视图流。
// 该渲染引擎通过以下核心功能点确保了知识内容的高效展示与沉浸式阅读体验：
// 1. 结构化块渲染：支持标题（H1-H6）、段落、列表、引用块、代码块及表格的差异化渲染，并自动适配系统的 WikiUI 设计规范。
// 2. 交互式内联解析：实现了 Wiki-link 内部链接、标准超链接、加粗、斜体及行内代码的混合解析，支持点击跳转至关联页面。
// 3. 多模态内容集成：深度集成了 Mermaid 绘图引擎与任务列表（Task List），支持在文档中直接嵌入动态图表与待办事项。
// 4. 安全与性能优化：内置了基于隐私模式的模糊遮罩逻辑，并利用 Skeleton View 提供流式生成阶段的视觉占位反馈。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，消除渲染器内部的魔鬼数字
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

@preconcurrency import SwiftUI

// MARK: - Markdown Renderer View
/// Renders structured Markdown blocks using MarkdownProcessor.
/// Parsing logic is extracted to MarkdownProcessor service for reuse.
@MainActor
struct MarkdownRendererView: View {
    @Environment(KMStore.self) var store
    let content: String
    let isPrivate: Bool
    let onLinkTap: (String) -> Void
    var isCompact: Bool = false

    @State private var tempUnlocked = false
    private let parser = MarkdownProcessor()

    var body: some View {
        Group {
            if content.isEmpty && store.llmService.isProcessing {
                renderSkeleton()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    let blocks = parser.parse(content)
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        renderBlock(block)
                    }
                }
            }
        }
        .blur(radius: (store.isPrivacyModeEnabled && isPrivate && !tempUnlocked) ? 12 : 0)
        .overlay {
            if store.isPrivacyModeEnabled && isPrivate && !tempUnlocked {
                VStack(spacing: WikiUI.medium) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: WikiUI.largeIconSize / 1.5))
                    Text(Localized.tr("security.privacyMasked"))
                        .font(WikiUI.titleFont)
                    Button(action: {
                        authenticate()
                    }) {
                        Label(Localized.tr("security.unlockToView"), systemImage: "lock.open.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.wikiAccent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.wikiText)
            }
        }
    }

    private func authenticate() {
        Task {
            if await store.securityService.authenticateWithBiometrics() {
                await MainActor.run {
                    withAnimation { tempUnlocked = true }
                    HapticFeedback.shared.trigger(.unlock)
                }
            }
        }
    }

    // MARK: - Block Renderer
    @ViewBuilder
    private func renderBlock(_ block: MarkdownProcessor.BlockType) -> some View {
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
        case .details(let summary, let content):
            renderDetailsBlock(summary: summary, content: content)
        }
    }

    @ViewBuilder
    private func renderDetailsBlock(summary: String, content: String) -> some View {
        DisclosureGroup {
            MarkdownRendererView(content: content, isPrivate: isPrivate, onLinkTap: onLinkTap, isCompact: true)
                .padding(.top, 4)
        } label: {
            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.wikiAccent)
        }
        .padding(12)
        .background(Color.wikiAccent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 4)
    }

    // MARK: - Render Heading
    private func renderHeading(text: String, level: Int) -> some View {
        let headingLevel = WikiUI.HeadingLevel(rawValue: level) ?? .h6
        let isMainTitle = level == 1
        
        return Text(text)
            .font(.system(size: headingLevel.size, design: .rounded).weight(headingLevel.weight))
            .foregroundStyle(.wikiText)
            .multilineTextAlignment(isMainTitle ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: isMainTitle ? .center : .leading)
            .padding(.top, isMainTitle ? WikiUI.widePadding : headingLevel.topPadding)
            .padding(.bottom, isMainTitle ? WikiUI.standardPadding : 4)
    }

    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineContent(text)
            .font(isCompact ? WikiUI.captionFont : .system(.body, design: .serif))
            .lineSpacing(WikiUI.tiny * 1.5)
            .foregroundStyle(.wikiText.opacity(0.9))
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
        let isAISummary = text.contains("AI") || text.hasPrefix("> AI")
        
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: WikiUI.tiny)
                .fill(isAISummary ? Color.wikiAccent : Color.wikiAccent.opacity(0.5))
                .frame(width: 3)
                .padding(.trailing, 10)

            renderInlineContent(text)
                .font(isAISummary ? .system(.body, design: .serif).italic() : .body.italic())
                .foregroundStyle(isAISummary ? .wikiAccent : .wikiSecondary)
                .lineSpacing(isAISummary ? WikiUI.small : WikiUI.tiny * 1.5) // AI 总结采用更宽松的行间距提升阅读舒适度

            Spacer(minLength: 0)
        }
        .padding(isAISummary ? 12 : 0)
        .background(isAISummary ? Color.wikiAccent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: isAISummary ? WikiUI.smallRadius : 0))
        .padding(.vertical, 4)
    }

    // MARK: - Render Code Block
    @ViewBuilder
    private func renderCodeBlock(code: String, language: String) -> some View {
        if language.lowercased() == "mermaid" {
            MermaidWebView(mermaidCode: code)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
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
    }

    // MARK: - Render Table
    @ViewBuilder
    private func renderTable(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                    renderInlineContent(cell)
                        .font(.system(.subheadline).weight(.semibold))
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
                            .font(.system(.subheadline))
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
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "wikilink" {
                    // 对于 wikilink://Title，Title 会被作为 host 解析（如果 Title 不包含特殊字符）
                    // 或者作为 path。更稳妥的方式是解析整个 URL 的内容。
                    let title = url.absoluteString
                        .replacingOccurrences(of: "wikilink://", with: "")
                        .removingPercentEncoding ?? ""
                    
                    if !title.isEmpty {
                        onLinkTap(title)
                    }
                    return .handled
                }
                return .systemAction
            })
    }
    
    private func buildAttributedString(from segments: [MarkdownProcessor.InlineSegment]) -> AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            var container = AttributedString(segment.content)
            
            switch segment.type {
            case .text:
                container.swiftUI.font = isCompact ? Font.footnote : Font.body
            case .bold:
                container.swiftUI.font = (isCompact ? Font.footnote : Font.body).weight(.bold)
            case .italic:
                container.swiftUI.font = (isCompact ? Font.footnote : Font.body).italic()
            case .code:
                container.swiftUI.font = .system(.caption, design: .monospaced)
                container.swiftUI.backgroundColor = Color.wikiAccent.opacity(0.15)
                container.swiftUI.foregroundColor = .wikiText
            case .wikilink:
                container.swiftUI.font = (isCompact ? Font.footnote : Font.body).weight(.medium)
                container.swiftUI.foregroundColor = Color.wikiAccent
                container.swiftUI.underlineStyle = .single
                if let encoded = segment.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    container.foundation.link = URL(string: "wikilink://\(encoded)")
                }
            case .link:
                let parts = segment.content.split(separator: "|")
                let label = String(parts.first ?? "")
                let urlString = String(parts.last ?? "")
                container = AttributedString(label)
                container.swiftUI.font = isCompact ? Font.footnote : Font.body
                container.swiftUI.foregroundColor = Color.wikiAccent
                container.swiftUI.underlineStyle = .single
                if let url = URL(string: urlString) {
                    container.foundation.link = url
                }
            case .emoji:
                container.swiftUI.font = .body
            }
            
            result.append(container)
        }
        
        return result
    }

    // MARK: - Skeleton View
    @ViewBuilder
    private func renderSkeleton() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.wikiCard)
                .frame(width: 200, height: 24)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.wikiCard.opacity(0.6))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                }
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.wikiCard.opacity(0.4))
                .frame(width: 150, height: 18)
        }
        .padding(.vertical, 8)
        .opacity(0.6)
    }
}
