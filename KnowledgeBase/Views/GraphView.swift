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
            .navigationTitle("知识图谱")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Text("\(filteredNodes.count) 节点 · \(filteredEdges.count) 连接")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)

                        Button(action: { showLegend.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.wikiSecondary)
                        }
                        .accessibilityIdentifier("toggle-legend")
                    }
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
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 48))
                .foregroundStyle(.wikiSecondary)
            Text("知识图谱")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.wikiText)
            Text("页面间的关联将在此可视化")
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            Text("在编辑页面时使用 [[页面名]] 即可建立链接")
                .font(.caption)
                .foregroundStyle(.wikiAccent.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.wikiAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        }
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
                let nodeSize: CGFloat = isSelected ? 40 : max(24, min(40, 20 + CGFloat(linkCount) * 3))

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
        .onAppear { graphSize = geometrySize }
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
                    FilterPill(title: "全部", isSelected: filterType == nil) {
                        withAnimation { filterType = nil }
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
    private var geometrySize: CGSize {
        CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 100)
    }

    private func layoutGraph() {
        let result = GraphLayoutEngine.layout(
            pages: store.pages,
            linkResolver: { title in store.pageByTitle(title) },
            canvasSize: graphSize.width > 0 ? graphSize : geometrySize
        )
        nodes = result.nodes
        edges = result.edges
    }
}
