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
    @State private var selectedNodeID: UUID?  ///< 当前选中的节点 ID
    @State private var nodes: [GraphNode] = []  ///< 布局后的节点列表
    @State private var edges: [GraphEdge] = []  ///< 布局后的边（连接）列表
    @State private var graphSize: CGSize = .zero  ///< 图形画布的实际尺寸
    @State private var scale: CGFloat = 1.0  ///< 当前缩放比例
    @State private var lastScale: CGFloat = 1.0  ///< 上次缩放操作前的缩放值（用于增量计算）
    @State private var offset: CGSize = .zero  ///< 当前画布偏移量（拖拽）
    @State private var lastOffset: CGSize = .zero  ///< 上次拖拽操作前的偏移量
    @State private var isAnimating = false  ///< 节点是否正在执行脉冲动画
    @State private var showLegend = false  ///< 是否显示图例
    @State private var filterType: PageType?  ///< 当前筛选的页面类型，nil 表示显示全部
    @StateObject private var tooltipManager = TooltipManager.shared  ///< 提示管理器（单例）
    
    // MARK: - Constants
    /// Minimum node size in graph
    private static let minNodeSize: CGFloat = 24
    /// Maximum node size in graph
    private static let maxNodeSize: CGFloat = 40
    /// Selected node size (larger than normal)
    private static let selectedNodeSize: CGFloat = 40
    /// Size increment per connection
    private static let nodeSizeIncrement: CGFloat = 3
    /// Base node size
    private static let nodeBaseSize: CGFloat = 20
    /// Geometry height offset for safe area
    private static let geometryHeightOffset: CGFloat = 100
    /// Geometry size used for initial layout
    private static let defaultGeometrySize = CGSize(
        width: UIScreen.main.bounds.width,
        height: UIScreen.main.bounds.height - 100
    )

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

                // 点阵背景装饰
                WikiDotPattern(dotColor: .wikiBorder, spacing: 24, dotSize: 2)
                    .opacity(0.35)

                if nodes.isEmpty {
                    emptyStateView
                } else {
                    graphCanvas
                }

                if !nodes.isEmpty {
                    zoomControls
                    typeFilterPills
                }

                if showLegend && !nodes.isEmpty {
                    legendOverlay
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

    // MARK: - Empty State
    private var emptyStateView: some View {
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

    // MARK: - Graph Canvas
    private var graphCanvas: some View {
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
                let linkCount = edges.filter { $0.source == node.id || $0.target == node.id }.count
                let nodeSize: CGFloat = isSelected ? Self.selectedNodeSize : max(Self.minNodeSize, min(Self.maxNodeSize, Self.nodeBaseSize + CGFloat(linkCount) * Self.nodeSizeIncrement))

                GraphNodeView(
                    node: node,
                    isSelected: isSelected,
                    isAnimating: isAnimating,
                    linkCount: linkCount
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedNodeID = selectedNodeID == node.id ? nil : node.id
                        isAnimating = selectedNodeID != nil
                    }
                }

                GraphNodeLabel(node: node, isSelected: isSelected, nodeSize: nodeSize)
            }
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = lastScale * value
                    scale = min(max(newScale, 0.5), 3.0)
                }
                .onEnded { _ in lastScale = scale }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
        .onAppear { graphSize = Self.defaultGeometrySize }
    }

    // MARK: - Zoom Controls
    private var zoomControls: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()
                GraphZoomControls(
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset
                ) { layoutGraph() }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Type Filter Pills
    private var typeFilterPills: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: Localized.tr("search.all"), isSelected: filterType == nil) {
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

    // MARK: - Legend Overlay
    private var legendOverlay: some View {
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

    // MARK: - Helpers

    /// 触发图形重新布局
    ///
    /// 当页面数据变化时（如增删改页面或链接）调用此方法重新计算布局。
    /// 内部调用 GraphLayoutEngine.layout 获取新的节点和边数据。
    private func layoutGraph() {
        let result = GraphLayoutEngine.layout(
            pages: store.pages,
            linkResolver: { title in store.pageByTitle(title) },
            canvasSize: graphSize.width > 0 ? graphSize : Self.defaultGeometrySize
        )
        nodes = result.nodes
        edges = result.edges
    }
}
