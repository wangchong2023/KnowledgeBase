// ChatComponents.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了 AI 助手界面的核心 UI 组件库（ChatComponents），负责构建对话气泡、流式交互效果及 Markdown 渲染逻辑。
// 该组件库通过以下功能点提升了对话系统的视觉表现力与交互连贯性：
// 1. 智能气泡系统：实现了支持用户、助手及系统角色的差异化气泡渲染（ChatBubbleView），具备自动时间戳标注与头像展示。
// 2. 交互式内容渲染：集成 Markdown 引擎并支持 Wiki-link 实时解析，点击链接可直接触发系统内的页面跳转。
// 3. 动态状态反馈：定义了语义化的脉冲动画（PulsingDot），用于在 AI 思考阶段提供直观的视觉进度反馈。
// 4. 引用关联展示：实现了可折叠的参考资料面板，自动根据页面类型进行归类展示，增强了 AI 响应的可信度。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 优化 PulsingDot 动画触发机制，完善符合架构规范的功能说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Chat Bubble View
/// 聊天气泡视图
/// 支持用户消息（右侧、渐变背景）与 AI 消息（左侧、卡片背景）的差异化渲染
struct ChatBubbleView: View {
    let message: ChatMessage
    let pages: [WikiPage]
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    @State private var referencesExpanded = false
    @Binding var selectedTab: AppTab
    
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.wikiAccent : Color.wikiSecondary)
                    .font(.title3)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Group {
                switch message.role {
                case .user:
                    userBubble
                case .assistant:
                    assistantBubble
                case .system:
                    systemBubble
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter.string(from: message.timestamp)
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(message.content)
                    .font(.footnote)
                    .foregroundStyle(.white)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [.wikiAccent, .wikiAccent.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
            .shadow(color: Color.wikiAccent.opacity(0.2), radius: 6, x: 0, y: 3)
            
            Text(timestampString)
                .font(.system(size: 10))
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 24)
    }
    
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("AI")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.wikiAccent)
                
                ChatContentView(text: message.content, pages: pages, selectedTab: $selectedTab)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WikiUI.mediumRadius)
                    .stroke(Color.wikiAccent.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            
            // Collapsible References Panel
            if !message.relatedPageIDs.isEmpty {
                referencesPanel
            }
            
            Text(timestampString)
                .font(.system(size: 10))
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 8)
    }
    
    /// Collapsible references panel showing cited wiki pages grouped by type
    private var referencesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with expand/collapse toggle
            Button(action: { withAnimation { referencesExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: referencesExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                    Text(referencesExpanded ? L10n.Chat.tr("referencesExpanded") : L10n.Chat.tr("referencesCollapsed"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)
                    Spacer()
                    Text("\(message.relatedPageIDs.count)")
                        .font(.caption2)
                        .foregroundStyle(.wikiAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.wikiAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("references-toggle")
            
            // Expanded references grouped by page type
            if referencesExpanded {
                let grouped = Dictionary(grouping: message.relatedPageIDs.compactMap { id in pages.first { $0.id == id } }) { $0.type }
                ForEach(PageType.allCases.filter { grouped[$0] != nil }, id: \.self) { type in
                    if let pagesOfType = grouped[type], !pagesOfType.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            // Type header
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption2)
                                Text(type.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(type.themedColor)
                            .padding(.top, 4)
                            
                            // Page chips
                            FlowLayout(spacing: 6) {
                                ForEach(pagesOfType, id: \.id) { page in
                                    Button(action: { 
                                        selectedTab = .wiki
                                        router.navigateToPage(id: page.id)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: page.displayIcon)
                                                .font(.caption2)
                                            Text(page.title)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(type.themedColor.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(type.themedColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.wikiCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.system(size: 11))
                .foregroundStyle(.wikiSecondary.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.wikiCard.opacity(0.5)))
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Chat Content View (renders wikilinks as tappable)
/// 聊天消息内容渲染引擎
/// 负责 Markdown 文本的解析、Wiki-link 的交互化处理及超长文本的折叠逻辑
struct ChatContentView: View {
    let text: String
    let pages: [WikiPage]
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    @State private var expanded = false
    @Binding var selectedTab: AppTab
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let displayText = expanded ? text : String(text.prefix(1500))
            
            MarkdownRendererView(content: displayText, isPrivate: false, onLinkTap: { title in
                let targetTitle = title.trimmingCharacters(in: .whitespaces)
                if let page = pages.first(where: { $0.title.localizedCaseInsensitiveCompare(targetTitle) == .orderedSame }) {
                    HapticFeedback.shared.trigger(.link)
                    selectedTab = .wiki
                    router.navigateToPage(id: page.id)
                }
            }, isCompact: true)
            
            if text.count > 1500 && !expanded {
                Button(L10n.Chat.tr("expandFull")) {
                    withAnimation { expanded = true }
                }
                .font(.caption)
                .foregroundStyle(.wikiAccent)
            }
        }
    }
}

// MARK: - Chat Link Parser
/// 从文本中提取 [[wikilink]] 的解析器，供 ChatView 和 ChatContentView 共用。
struct ChatLinkParser {
    struct TextSegment {
        let text: String
        let isLink: Bool
    }
    
    /// 从文本中提取所有 [[wikilink]] 标题。
    static func extractWikiLinks(from text: String) -> [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }
    
    /// 将文本解析为交替的普通文本和 wikilink 片段。
    static func parseSegments(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [TextSegment(text: text, isLink: false)]
        }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        
        var lastEnd = 0
        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !before.isEmpty {
                    segments.append(TextSegment(text: before, isLink: false))
                }
            }
            
            if match.numberOfRanges > 1 {
                let linkText = nsText.substring(with: match.range(at: 1))
                segments.append(TextSegment(text: linkText, isLink: true))
            }
            
            lastEnd = match.range.location + match.range.length
        }
        
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            if !remaining.isEmpty {
                segments.append(TextSegment(text: remaining, isLink: false))
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text, isLink: false)] : segments
    }
}

// MARK: - Pulsing Dot Animation
/// 脉冲缩放动画修饰符
/// 用于在 AI 思考或加载状态下提供平滑的视觉律动反馈
struct PulsingDot: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.0 : 0.6)
            .opacity(isAnimating ? 1.0 : 0.3)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                withAnimation {
                    isAnimating = true
                }
            }
    }
}
