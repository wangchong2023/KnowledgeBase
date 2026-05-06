// PageDetailHeader.swift
//
// 作者: Wang Chong
// 功能说明: Page detail header displaying type/status/confidence badges, title, aliases, tags, and meta info.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Page Detail Header
/// Page detail header displaying type/status/confidence badges, title, aliases, tags, and meta info.
/// 页面详情顶栏组件
/// 负责展示知识页面的标题、类型标识、最近修改时间及操作入口（如书签、分享、删除）
/// 页面详情页顶部头部组件
/// 负责在详情页显著位置展示核心元数据（标题、类型、状态、置信度、别名、标签及统计信息），支持 Hero 动画
struct PageDetailHeader: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID? = nil
    @ObservedObject private var taskCenter = TaskCenter.shared
    
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
            
            // AI Status Indicator
            if taskCenter.tasks.contains(where: { if case .running = $0.status { return true }; return false }) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 10))
                    Text(L10n.AI.Task.tr("status.running"))
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.wikiAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.wikiAccent.opacity(0.1))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale))
            }

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
            TypeBadge(page: page, heroNamespace: heroNamespace)
            
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
/// 页面类型标识徽章小组件
/// 负责以胶囊形态展示页面所属分类图标及名称，并适配 Hero 动画转场标识
private struct TypeBadge: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID?
    
    var body: some View {
        HStack(spacing: 4) {
            if let ns = heroNamespace {
                Image(systemName: page.displayIcon)
                    .font(.caption)
                    .matchedGeometryEffect(id: page.id, in: ns)
            } else {
                Image(systemName: page.displayIcon)
                    .font(.caption)
            }
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
/// 页面状态标识徽章小组件
/// 负责展示页面的生命周期状态（如草稿、已发布、已废弃），并提供颜色编码的视觉提示
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
/// 页面置信度标识徽章小组件
/// 负责展示内容的可靠性指标，通常由 AI 自动打分或人工审核确认
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
