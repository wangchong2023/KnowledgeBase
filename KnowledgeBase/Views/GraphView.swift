import SwiftUI

/// 图形可视化容器视图
///
/// 以力导向图的形式展示知识库中所有页面之间的链接关系。
///
/// ## 主要功能
/// - 页面节点的网络布局可视化
/// - 节点类型筛选（按 PageType 过滤显示）
/// - 缩放和平移交互
/// - 节点选择和高亮
/// - 连接线（边）的可视化
///
/// ## 布局引擎
/// 底层使用 GraphLayoutEngine 进行力导向布局计算，
/// 节点位置根据链接关系自动分布，相互链接的节点会靠近。
///
/// ## 节点大小
/// 节点大小根据连接数动态计算：
/// - 基础大小：20pt
/// - 每增加一条连接 +3pt
/// - 最小 24pt，最大 40pt
/// - 选中节点固定 40pt
struct GraphContainerView: View {
    @EnvironmentObject var store: KMStore
    @State private var selectedNodeID: UUID?
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var graphSize: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var showLegend = false
    @State private var filterType: PageType?
    @StateObject private var tooltipManager = TooltipManager.shared

    // MARK: - Constants
    private static let minNodeSize: CGFloat = 24
    private static let maxNodeSize: CGFloat = 40
    private static let selectedNodeSize: CGFloat = 40
    private static let nodeSizeIncrement: CGFloat = 3
    private static let nodeBaseSize: CGFloat = 20
    private static let geometryHeightOffset: CGFloat = 100

    var filteredNodes: [GraphNode] {
        guard let filter = filterType else { return nodes }
        return nodes.filter { $0.type == filter }
    }

    var filteredEdges: [GraphEdge] {
        guard filterType != nil else { return edges }
        let filteredIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { filteredIDs.contains($0.source) && filteredIDs.contains($0.target) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wikiBackground.ignoresSafeArea()
                WikiDotPattern(dotColor: .wikiBorder, spacing: 24, dotSize: 2)
                    .opacity(0.35)

                if nodes.isEmpty {
                    GraphEmptyStateView()
                } else {
                    GraphCanvasView(
                        filteredNodes: filteredNodes,
                        filteredEdges: filteredEdges,
                        selectedNodeID: $selectedNodeID,
                        isAnimating: $isAnimating,
                        scale: $scale,
                        offset: $offset,
                        graphSize: $graphSize,
                        defaultGeometrySize: graphSize.width > 0 ? graphSize : CGSize(width: 400, height: 600)
                    ) { node in
                        withAnimation(.spring(response: 0.5)) {
                            selectedNodeID = selectedNodeID == node.id ? nil : node.id
                            isAnimating = selectedNodeID != nil
                        }
                    }
                }

                if !nodes.isEmpty {
                    GraphZoomControlsView(
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        onRelayout: layoutGraph
                    )
                    GraphFilterPillsView(
                        filterType: $filterType,
                        tooltipManager: tooltipManager
                    )
                }

                if showLegend && !nodes.isEmpty {
                    GraphLegendView()
                }

                if let selectedID = selectedNodeID,
                   let page = store.pageByID(selectedID) {
                    VStack {
                        Spacer()
                        GraphSelectedNodeCard(page: page)
                    }
                }
            }
            .navigationTitle(Localized.tr("graph.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Text(Localized.trf("graph.nodesConnections", filteredNodes.count, filteredEdges.count))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                            .fixedSize()

                        Button(action: { showLegend.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.wikiSecondary)
                        }
                        .accessibilityIdentifier("toggle-legend")
                    }
                    .padding(.horizontal, 8)
                    .padding(.trailing, 4)
                }
            }
        }
        .onAppear { layoutGraph() }
        .onChange(of: store.pages.count) { _, _ in
            withAnimation(.spring(response: 0.6)) { layoutGraph() }
        }
    }

    private func layoutGraph() {
        let result = GraphLayoutEngine.layout(
            pages: store.pages,
            linkResolver: { title in store.pageByTitle(title) },
            canvasSize: graphSize.width > 0 ? graphSize : CGSize(width: 400, height: 600)
        )
        nodes = result.nodes
        edges = result.edges
    }
}

// MARK: - Graph Empty State
private struct GraphEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.opacity(0.07))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.wikiAccent.opacity(0.04))
                    .frame(width: 160, height: 160)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(height: 100)

            VStack(spacing: 8) {
                Text(Localized.tr("graph.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text(Localized.tr("graph.emptyDesc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
            }

            Text(Localized.tr("graph.linkHint"))
                .font(.caption)
                .foregroundStyle(.wikiAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: WikiUI.chipRadius)
                        .fill(Color.wikiAccent.opacity(0.1))
                )
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Graph Canvas View
private struct GraphCanvasView: View {
    let filteredNodes: [GraphNode]
    let filteredEdges: [GraphEdge]
    @Binding var selectedNodeID: UUID?
    @Binding var isAnimating: Bool
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var graphSize: CGSize
    let defaultGeometrySize: CGSize
    let onNodeTap: (GraphNode) -> Void

    private static let minNodeSize: CGFloat = 24
    private static let maxNodeSize: CGFloat = 40
    private static let selectedNodeSize: CGFloat = 40
    private static let nodeSizeIncrement: CGFloat = 3
    private static let nodeBaseSize: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = CGSize(
                width: max(geometry.size.width, graphSize.width),
                height: max(geometry.size.height, graphSize.height)
            )

            Canvas { context, _ in
                for edge in filteredEdges {
                    guard let sourceNode = filteredNodes.first(where: { $0.id == edge.source }),
                          let targetNode = filteredNodes.first(where: { $0.id == edge.target }) else { continue }

                    let sourcePoint = sourceNode.position
                    let targetPoint = targetNode.position

                    var path = Path()
                    path.move(to: sourcePoint)
                    path.addLine(to: targetPoint)

                    let isSelectedEdge = selectedNodeID == edge.source || selectedNodeID == edge.target

                    if isSelectedEdge {
                        context.stroke(path, with: .color(.wikiAccent.opacity(0.3)), lineWidth: 4)
                    }

                    context.stroke(
                        path,
                        with: .color(isSelectedEdge ? .wikiAccent.opacity(0.7) : .wikiBorder.opacity(0.35)),
                        lineWidth: isSelectedEdge ? 2.5 : 1
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ForEach(filteredNodes) { node in
                let isSelected = selectedNodeID == node.id
                let linkCount = filteredEdges.filter { $0.source == node.id || $0.target == node.id }.count
                let nodeSize: CGFloat = isSelected ? Self.selectedNodeSize : max(Self.minNodeSize, min(Self.maxNodeSize, Self.nodeBaseSize + CGFloat(linkCount) * Self.nodeSizeIncrement))

                GraphNodeView(
                    node: node,
                    isSelected: isSelected,
                    isAnimating: isAnimating,
                    linkCount: linkCount
                ) {
                    onNodeTap(node)
                }

                GraphNodeLabel(node: node, isSelected: isSelected, nodeSize: nodeSize)
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = scale * value
                    scale = min(max(newScale, 0.5), 3.0)
                }
                .onEnded { _ in }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    )
                }
                .onEnded { _ in }
        )
        .onAppear { graphSize = CGSize(width: 400, height: 600) }
    }
}

// MARK: - Graph Zoom Controls View
private struct GraphZoomControlsView: View {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let onRelayout: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GraphZoomControls(
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset,
                    onRelayout: onRelayout
                )
                .padding(.trailing, 16)
            }
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Graph Filter Pills View
private struct GraphFilterPillsView: View {
    @Binding var filterType: PageType?
    @ObservedObject var tooltipManager: TooltipManager

    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: Localized.tr("search.all"), isSelected: filterType == nil) {
                        HapticManager.selection()
                        withAnimation { filterType = nil }
                        if !tooltipManager.isShown(.graphFilter) {
                            withAnimation { tooltipManager.activeTooltip = .graphFilter }
                        }
                    }

                    ForEach(PageType.allCases) { type in
                        FilterPill(
                            title: type.displayName,
                            icon: type.icon,
                            color: type.themedColor,
                            isSelected: filterType == type
                        ) {
                            HapticManager.selection()
                            withAnimation { filterType = type }
                        }
                        .accessibilityIdentifier("Filter-\(type.rawValue)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)

            Spacer()
        }
        .overlay(alignment: .top) {
            if tooltipManager.activeTooltip == .graphFilter {
                VStack {
                    HStack {
                        Spacer()
                        WikiTooltip(
                            title: Localized.tr(tooltipManager.activeTooltip?.titleKey ?? ""),
                            description: Localized.tr(tooltipManager.activeTooltip?.descriptionKey ?? ""),
                            icon: tooltipManager.activeTooltip?.icon ?? "questionmark",
                            arrowDirection: .bottom,
                            accentColor: .wikiAccent
                        )
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .padding(.top, 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { tooltipManager.activeTooltip = nil }
                    tooltipManager.markShown(.graphFilter)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tooltipManager.activeTooltip)
    }
}

// MARK: - Graph Legend View
private struct GraphLegendView: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                GraphLegend()
                    .padding(.trailing, 16)
            }
            .padding(.top, 50)
            Spacer()
        }
    }
}
