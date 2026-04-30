import SwiftUI

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
            .navigationTitle(L.tr("graph.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Text(L.trf("graph.nodesConnections", filteredNodes.count, filteredEdges.count))
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
                Text(L.tr("graph.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text(L.tr("graph.emptyDesc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
            }

            Text(L.tr("graph.linkHint"))
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
                    FilterPill(title: L.tr("search.all"), isSelected: filterType == nil) {
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
                            title: L.tr(tooltipManager.activeTooltip?.titleKey ?? ""),
                            description: L.tr(tooltipManager.activeTooltip?.descriptionKey ?? ""),
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
