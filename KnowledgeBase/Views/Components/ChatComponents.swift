import SwiftUI

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    let pages: [WikiPage]
    @EnvironmentObject var store: KMStore
    
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
            Image(systemName: "brain.head.profile.fill")
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
                
                if !message.relatedPageIDs.isEmpty {
                    relatedPagesChips
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Spacer(minLength: 40)
        }
    }
    
    private var relatedPagesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(message.relatedPageIDs, id: \.self) { pageID in
                    if let page = pages.first(where: { $0.id == pageID }) {
                        Button(action: { store.selectedPageID = page.id }) {
                            HStack(spacing: 4) {
                                Image(systemName: page.displayIcon)
                                    .font(.caption2)
                                Text(page.title)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(page.type.themedColor.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(page.type.themedColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
                            store.selectedPageID = page.id
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(segment.text)
                                .font(.subheadline.weight(.medium))
                                .underline()
                        }
                        .foregroundStyle(.wikiAccent)
                    }
                    .buttonStyle(.plain)
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
