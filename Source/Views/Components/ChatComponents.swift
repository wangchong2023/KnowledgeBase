import SwiftUI

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    let pages: [WikiPage]
    @EnvironmentObject var store: KMStore
    @State private var referencesExpanded = false
    
    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .system:
            systemBubble
        }
    }
    
    private var userBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer(minLength: 40)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Image(systemName: "person.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(width: 28, height: 28)
                .background(Color.wikiAccent.opacity(0.15))
                .clipShape(Circle())
        }
    }
    
    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(width: 28, height: 28)
                .background(Color.wikiAccent.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                ChatContentView(text: message.content, pages: pages)
                    .padding(12)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
                
                // Collapsible References Panel
                if !message.relatedPageIDs.isEmpty {
                    referencesPanel
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Spacer(minLength: 40)
        }
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
                    Text(referencesExpanded ? Localized.tr("chat.referencesExpanded") : Localized.tr("chat.referencesCollapsed"))
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
                                    Button(action: { store.selectedPageID = page.id }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: page.displayIcon)
                                                .font(.caption2)
                                            Text(page.title)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(type.themedColor.opacity(0.15))
                                        .clipShape(Capsule())
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
        Text(message.content)
            .font(.caption)
            .foregroundStyle(.wikiSecondary)
            .padding(.horizontal, 20)
    }
}

// MARK: - Chat Content View (renders wikilinks as tappable)
struct ChatContentView: View {
    let text: String
    let pages: [WikiPage]
    @EnvironmentObject var store: KMStore
    @State private var expanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let displayText = expanded ? text : String(text.prefix(600))
            
            renderText(displayText)
            
            if text.count > 600 && !expanded {
                Button(Localized.tr("chat.expandFull")) {
                    withAnimation { expanded = true }
                }
                .font(.caption)
                .foregroundStyle(.wikiAccent)
            }
        }
    }
    
    @ViewBuilder
    private func renderText(_ text: String) -> some View {
        let segments = ChatLinkParser.parseSegments(text)
        
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if segment.isLink {
                    Button(action: {
                        if let page = pages.first(where: { $0.title == segment.text }) {
                            HapticManager.shared.trigger(.link)
                            store.selectedPageID = page.id
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 10))
                            Text(segment.text)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.wikiAccent.opacity(0.15))
                        .foregroundStyle(.wikiAccent)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.wikiAccent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                } else {
                    Text(segment.text)
                        .font(.subheadline)
                        .foregroundStyle(.wikiText)
                        .tint(.wikiAccent)
                }
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
struct PulsingDot: ViewModifier {
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(0.4)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: true
            )
    }
}
