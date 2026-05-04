// GraphComponents.swift
//
// 作者: Wang Chong
// 功能说明: 图谱中的单个节点渲染。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Graph Node View
/// 图谱中的单个节点渲染。
struct GraphNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isAnimating: Bool
    let linkCount: Int
    let clusters: [GraphClusteringService.Cluster]
    let useClustering: Bool
    let onSelect: () -> Void
    var heroNamespace: Namespace.ID
    @State private var isHovered = false
    
    // 视口裁剪参数
    let viewportRect: CGRect? // 当前可见区域
    let scale: CGFloat
    
    private var isVisible: Bool {
        guard let rect = viewportRect else { return true }
        // 简单的包围盒检测
        let margin: CGFloat = 50.0
        return rect.insetBy(dx: -margin, dy: -margin).contains(node.position)
    }

    private var nodeSize: CGFloat {
        isSelected ? 40 : max(24, min(40, 20 + CGFloat(linkCount) * 3))
    }

    var body: some View {
        Group {
            if isVisible {
                let nodeBaseColor = useClustering ? (clusters.first(where: { $0.pageIDs.contains(node.id) })?.color ?? node.type.themedColor) : node.type.themedColor
                let nodeSize: CGFloat = isSelected ? 40 : 28
                let isLowDetail = scale < AppConfig.UI.graphLODZoomThreshold // LOD 阈值
                
                ZStack {
                    if isLowDetail {
                        // LOD: 远景模式 - 仅显示纯色圆点，极致性能
                        Circle()
                            .fill(nodeBaseColor)
                            .frame(width: nodeSize * 0.6, height: nodeSize * 0.6)
                    } else {
                        nodeContent
                    }
                }
                .position(node.position)
                .onTapGesture { 
                    HapticManager.shared.trigger(.link)
                    onSelect() 
                }
            }
        }
    }
    
    private var nodeContent: some View {
        ZStack {
            let nodeBaseColor = useClustering ? (clusters.first(where: { $0.pageIDs.contains(node.id) })?.color ?? node.type.themedColor) : node.type.themedColor

            // 1. 深度发光 (Aura Effect)
            if isSelected {
                Circle()
                    .fill(nodeBaseColor.opacity(0.2))
                    .frame(width: nodeSize * 2.0, height: nodeSize * 2.0)
                    .blur(radius: 15)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            }

            // 2. 核心脉冲 (Core Pulse)
            if isSelected {
                Circle()
                    .stroke(nodeBaseColor.opacity(0.5), lineWidth: 2)
                    .frame(width: nodeSize, height: nodeSize)
                    .scaleEffect(isAnimating ? 2.0 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)
            }

            // 3. 节点本体 (Node Body)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [nodeBaseColor.opacity(0.7), nodeBaseColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                #if os(iOS)
                .matchedGeometryEffect(id: node.id, in: heroNamespace, isSource: true)
                #endif
                .frame(width: nodeSize, height: nodeSize)
                .onHover { hovering in
                    withAnimation(.spring()) {
                        isHovered = hovering
                    }
                    if hovering {
                        HapticManager.shared.trigger(.selection)
                    }
                }
                .overlay {
                    if isHovered {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.title)
                                .font(.caption.bold())
                            Text(node.type.displayName)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .offset(y: -35)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .contextMenu {
                    Button(action: { onSelect() }) {
                        Label(L10n.Graph.tr("viewDetail"), systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button(action: {
                        let link = "[[\(node.title)]]"
                        #if os(iOS)
                        UIPasteboard.general.string = link
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                        #endif
                    }) {
                        Label(L10n.Graph.tr("copyWikiLink"), systemImage: "link")
                    }
                    
                    Divider()
                    
                    #if os(macOS)
                    Button(action: {
                        // macOS 新窗口功能预留
                    }) {
                        Label(L10n.Common.tr("openInNewWindow"), systemImage: "macwindow.badge.plus")
                    }
                    #endif
                }
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: nodeBaseColor.opacity(isSelected ? 0.8 : 0.4), radius: isSelected ? 15 : 6)
                .scaleEffect(isSelected ? 1.1 : 1.0)

            // 4. 类型图标
            Image(systemName: node.type.icon)
                .font(.system(size: isSelected ? 16 : 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .onTapGesture {
            HapticManager.shared.trigger(.link)
            onSelect()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.title), \(node.type.displayName)")
        .accessibilityValue(L10n.Graph.trf("linksCountFormat", linkCount))
        .accessibilityHint(L10n.Graph.tr("accessibility.nodeHint"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityAction { onSelect() }
    }
}

// MARK: - Graph Node Label
/// 节点标题标签。iPad 大屏幕下字号适当放大。
struct GraphNodeLabel: View {
    let node: GraphNode
    let isSelected: Bool
    let nodeSize: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 大屏幕下字号从 10pt 提升到 12pt
    private var fontSize: CGFloat {
        horizontalSizeClass == .regular ? 12 : 10
    }

    var body: some View {
        Text(node.title)
            .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? .wikiText : .wikiSecondary)
            .lineLimit(1)
            .position(x: node.position.x, y: node.position.y + nodeSize / 2 + 14)
            .accessibilityHidden(true) // 节点图标已包含信息，标签设为隐藏以防冗余
    }
}

// MARK: - Graph Zoom Controls
/// 缩放控制栏。
struct GraphZoomControls: View {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var show3D: Bool
    let onRelayout: () -> Void
    let onFitToScreen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation { scale = max(0.5, scale - 0.2) }
                lastScale = scale
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("zoom-out")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation { scale = min(3.0, scale + 0.2) }
                lastScale = scale
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("zoom-in")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }) {
                Image(systemName: "scope")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("reset")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation(.spring(response: 0.5)) { onFitToScreen() }
            }) {
                Image(systemName: "viewfinder")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("fit-to-screen")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation(.spring(response: 0.6)) { onRelayout() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("relayout")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: { show3D = true }) {
                Image(systemName: "view.3d")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("graph-3d")
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Graph Legend
/// 图谱图例，支持类型与聚类两种模式。
struct GraphLegend: View {
    let useClustering: Bool
    let clusters: [GraphClusteringService.Cluster]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.caption)
                    .foregroundStyle(.wikiAccent)
                Text(L10n.Graph.tr("legend"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.wikiText)
            }
            .padding(.bottom, 2)
            
            if useClustering {
                ForEach(clusters) { cluster in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(cluster.color)
                            .frame(width: 10, height: 10)
                        Text(cluster.name)
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
            } else {
                ForEach(PageType.allCases) { type in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(type.themedColor)
                            .frame(width: 10, height: 10)
                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// MARK: - Graph Selected Node Card
/// 选中节点的详情卡片。
struct GraphSelectedNodeCard: View {
    let page: WikiPage
    var heroNamespace: Namespace.ID? = nil

    var body: some View {
        NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
            cardContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            Image(systemName: page.displayIcon)
                .foregroundStyle(page.type.themedColor)
                .frame(width: 36, height: 36)
                .background(page.type.themedColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text("\(page.type.displayName) · \(page.wordCount) \(Localized.tr("page.wordCountUnit")) · \(page.outgoingLinks.count) \(Localized.tr("page.outLinkUnit"))")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.wikiSecondary)
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

// MARK: - Graph Insights Panel
/// 图谱洞察面板，显示知识库的发现结果：意外关联、孤立页面、稀疏社区、桥接节点。
struct GraphInsightsPanel: View {
    let surprising: [UUID]
    let orphans: [UUID]
    let sparse: [UUID]
    let bridges: [UUID]
    let nodes: [GraphNode]
    let onSelectNode: (UUID) -> Void
    
    @State private var expandedSections: Set<String> = ["surprising", "orphans", "sparse", "bridges"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                    insightSection(
                        id: "surprising",
                        icon: "link Badge",
                        title: L10n.Graph.tr("insightSurprising"),
                        count: surprising.count,
                        description: L10n.Graph.tr("insightSurprisingDesc"),
                        color: .wikiComparison
                    )
                    
                    insightSection(
                        id: "orphans",
                        icon: "questionmark.circle",
                        title: L10n.Graph.tr("insightOrphans"),
                        count: orphans.count,
                        description: L10n.Graph.tr("insightOrphansDesc"),
                        color: .wikiSecondary
                    )
                    
                    insightSection(
                        id: "sparse",
                        icon: "chart.bar.xaxis",
                        title: L10n.Graph.tr("insightSparse"),
                        count: sparse.count,
                        description: L10n.Graph.tr("insightSparseDesc"),
                        color: .orange
                    )
                    
                    insightSection(
                        id: "bridges",
                        icon: "arrow.triangle.branch",
                        title: L10n.Graph.tr("insightBridges"),
                        count: bridges.count,
                        description: L10n.Graph.tr("insightBridgesDesc"),
                        color: .wikiAccent
                    )
                }
                .padding()
            }
            .background(Color.wikiBackground)
        }
    
    private func insightSection(id: String, icon: String, title: String, count: Int, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Button(action: {
                withAnimation { 
                    if expandedSections.contains(id) {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.wikiText)
                    
                    Text("\(count)")
                        .font(.footnote)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Image(systemName: expandedSections.contains(id) ? "chevron.down" : "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.wikiSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insight-\(id)")
            
            if expandedSections.contains(id) {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.leading, 32)
                
                // Node chips
                let nodeIDs = getNodeIDs(for: id)
                if !nodeIDs.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(nodeIDs, id: \.self) { nodeID in
                            if let node = nodes.first(where: { $0.id == nodeID }) {
                                Button(action: { onSelectNode(nodeID) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: node.type.icon)
                                            .font(.footnote)
                                        Text(node.title)
                                            .font(.footnote)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(color.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(color)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.leading, 32)
                }
            }
        }
        .padding(12)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
    }
    
    private func getNodeIDs(for section: String) -> [UUID] {
        switch section {
        case "surprising": return surprising
        case "orphans": return orphans
        case "sparse": return sparse
        case "bridges": return bridges
        default: return []
        }
    }
}
