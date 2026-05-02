@preconcurrency import SwiftUI
import LocalAuthentication

// MARK: - Markdown Renderer View
/// Renders structured Markdown blocks using MarkdownParser.
/// Parsing logic is extracted to MarkdownParser service for reuse.
@MainActor
struct MarkdownRendererView: View {
    @Environment(KMStore.self) var store
    let content: String
    let isPrivate: Bool
    let onLinkTap: (String) -> Void

    @State private var tempUnlocked = false
    private let laContext = LAContext()
    private let parser = MarkdownParser()

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
                VStack(spacing: 12) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 32))
                    Text(Localized.tr("security.privacyMasked"))
                        .font(.headline)
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
        var error: NSError?
        if laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            laContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: Localized.tr("security.unlockReason")) { success, _ in
                if success {
                    DispatchQueue.main.async {
                        withAnimation { tempUnlocked = true }
                        HapticManager.shared.trigger(.unlock)
                    }
                }
            }
        } else {
            // Fallback to passcode or just show it if biometrics not available
            withAnimation { tempUnlocked = true }
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
        let style: Font.TextStyle = level == 1 ? .title : (level == 2 ? .title2 : .title3)
        let weight: Font.Weight = level == 1 ? .bold : .semibold
        
        Text(text)
            .font(.system(style, design: .rounded).weight(weight))
            .foregroundStyle(.wikiText)
            .padding(.top, level == 1 ? 16 : 8)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineContent(text)
            .font(.system(.body, design: .serif))
            .lineSpacing(6)
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
            RoundedRectangle(cornerRadius: WikiUI.hairlineRadius)
                .fill(isAISummary ? Color.wikiAccent : Color.wikiAccent.opacity(0.5))
                .frame(width: 3)
                .padding(.trailing, 10)

            renderInlineContent(text)
                .font(isAISummary ? .system(.body, design: .serif).italic() : .body.italic())
                .foregroundStyle(isAISummary ? .wikiAccent : .wikiSecondary)
                .lineSpacing(isAISummary ? 8 : 6) // AI 总结采用更宽松的行间距提升阅读舒适度

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
    
    private func buildAttributedString(from segments: [MarkdownParser.InlineSegment]) -> AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            var container = AttributedString(segment.content)
            
            switch segment.type {
            case .text:
                container.swiftUI.font = .body
            case .bold:
                container.swiftUI.font = .body.weight(.bold)
            case .italic:
                container.swiftUI.font = .body.italic()
            case .code:
                container.swiftUI.font = .system(.caption, design: .monospaced)
                container.swiftUI.backgroundColor = Color.wikiAccent.opacity(0.15)
                container.swiftUI.foregroundColor = .wikiText
            case .wikilink:
                container.swiftUI.font = .body.weight(.medium)
                container.swiftUI.foregroundColor = .wikiAccent
                container.swiftUI.underlineStyle = .single
                // 我们在 Text 上无法直接捕获这个特定属性的点击，
                // 但我们可以通过转换整个 Text 为 Link 或使用自定义属性。
                // 暂时使用标准 link 属性，由外部 onLinkTap 处理或通过自定义 URL 协议。
                if let encoded = segment.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    container.foundation.link = URL(string: "wikilink://\(encoded)")
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
