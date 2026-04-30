import SwiftUI

// MARK: - Page Detail Header
/// Page detail header displaying type/status/confidence badges, title, aliases, tags, and meta info.
struct PageDetailHeader: View {
    let page: WikiPage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            breadcrumb
            typeStatusConfidenceRow
            titleView
            aliasesView
            tagsView
            metaInfoView
        }
        .padding()
    }
    
    // MARK: - Breadcrumb
    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Image(systemName: "books.vertical.fill")
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
            Text(Localized.tr("page.wiki"))
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 8))
                .foregroundStyle(.wikiSecondary)
            Text(page.type.displayName)
                .font(.caption2)
                .foregroundStyle(page.type.themedColor)
            if page.isPinned {
                Spacer()
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.wikiComparison)
            }
        }
    }
    
    // MARK: - Type / Status / Confidence Row
    private var typeStatusConfidenceRow: some View {
        HStack(spacing: 10) {
            // Type badge
            TypeBadge(page: page)
            
            // Status badge
            StatusBadge(page: page)
            
            // Confidence badge
            ConfidenceBadge(page: page)
            
            Spacer()
        }
    }
    
    // MARK: - Title
    private var titleView: some View {
        Text(page.title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.wikiText)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(Localized.trf("page.titleAccessibility", page.title))
    }
    
    // MARK: - Aliases
    @ViewBuilder
    private var aliasesView: some View {
        if !page.aliases.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.branch")
                        .font(.caption2)
                        .foregroundStyle(.wikiSource)
                    ForEach(page.aliases, id: \.self) { alias in
                        Text(alias)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.wikiSource.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(.wikiSource)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Localized.trf("page.aliasAccessibility", page.aliases.joined(separator: ", ")))
            }
        }
    }
    
    // MARK: - Tags
    @ViewBuilder
    private var tagsView: some View {
        if !page.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(page.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.wikiAccent.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(.wikiAccent)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Localized.trf("page.tagsAccessibility", page.tags.map { "#\($0)" }.joined(separator: ", ")))
            }
        }
    }
    
    // MARK: - Meta Info
    private var metaInfoView: some View {
        HStack(spacing: 16) {
            Label(Localized.trf("page.createdFormat", page.created.formatted(date: .abbreviated, time: .omitted)), systemImage: "calendar")
            Label(Localized.trf("page.updatedFormat", page.updated.formatted(date: .abbreviated, time: .omitted)), systemImage: "clock")
            Label(Localized.trf("page.wordCount", page.wordCount), systemImage: "textformat")
            Label(Localized.trf("page.outLinksCount", page.outgoingLinks.count), systemImage: "link")
        }
        .font(.caption)
        .foregroundStyle(.wikiSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Localized.trf("page.metaAccessibility", page.created.formatted(date: .abbreviated, time: .omitted), page.wordCount, page.outgoingLinks.count))
    }
}

// MARK: - Type Badge
private struct TypeBadge: View {
    let page: WikiPage
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: page.displayIcon)
                .font(.caption)
            Text(page.type.displayName)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(page.type.themedColor.opacity(0.2))
        .clipShape(Capsule())
        .foregroundStyle(page.type.themedColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Localized.trf("page.typeAccessibility", page.type.displayName))
    }
}

// MARK: - Status Badge
private struct StatusBadge: View {
    let page: WikiPage
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(page.status.color)
                .frame(width: 6, height: 6)
            Text(page.status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(page.status.color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(page.status.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Localized.trf("page.statusAccessibility", page.status.displayName))
    }
}

// MARK: - Confidence Badge
private struct ConfidenceBadge: View {
    let page: WikiPage
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "signal")
                .font(.caption2)
            Text(page.confidence.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(page.confidence.color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(page.confidence.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Localized.trf("page.confidenceAccessibility", page.confidence.displayName))
    }
}
