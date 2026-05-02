import SwiftUI

/// 图形可视化容器视图
struct GraphContainerView: View {
    @EnvironmentObject var store: KMStore
    @State private var selectedNodeID: UUID?
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var graphSize: CGSize = CGSize(width: 400, height: 600)
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var showLegend = false
    @State private var showInsights = false
    @State private var useClustering = false
    @State private var filterType: PageType?
    @StateObject private var tooltipManager = TooltipManager.shared
    
    @State private var insightSurprising: [UUID] = []
    @State private var insightOrphans: [UUID] = []
    @State private var insightSparse: [UUID] = []
    @State private var insightBridges: [UUID] = []

    // 辅助计算：解耦复杂表达式
    private func getFilteredNodes() -> [GraphNode] {
        guard let filter = filterType else { return nodes }
        return nodes.filter { $0.type == filter }
    }

    private func getFilteredEdges(for filteredNodes: [GraphNode]) -> [GraphEdge] {
        guard filterType != nil else { return edges }
        let filteredIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { edge in
            filteredIDs.contains(edge.source) && filteredIDs.contains(edge.target)
        }
    }

    var body: some View {
        let currentFilteredNodes = getFilteredNodes()
        let currentFilteredEdges = getFilteredEdges(for: currentFilteredNodes)
        
        ZStack {
                Color.wikiBackground.ignoresSafeArea()
                WikiDotPattern(dotColor: .wikiBorder, spacing: 24, dotSize: 2)
                    .opacity(0.35)

                if nodes.isEmpty {
                    GraphEmptyStateView()
                } else {
                    GraphCanvasView(
                        filteredNodes: currentFilteredNodes,
                        filteredEdges: currentFilteredEdges,
                        clusters: store.clusters,
                        useClustering: useClustering,
                        selectedNodeID: $selectedNodeID,
                        isAnimating: $isAnimating,
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        graphSize: $graphSize
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
                    GraphLegendView(useClustering: useClustering, clusters: store.clusters)
                }
                
                if let selectedID = selectedNodeID,
                   let page = store.pages.first(where: { $0.id == selectedID }) {
                    VStack {
                        Spacer()
                        GraphSelectedNodeCard(page: page)
                    }
                }
        }
        .navigationTitle(Localized.tr("graph.title"))
        .sheet(isPresented: $showInsights) {
            insightsPanel
        }
        .toolbar {
            graphToolbar
        }
        .onAppear { layoutGraph() }
        .onChange(of: store.pages.count) { _, _ in
            withAnimation(.spring(response: 0.6)) { layoutGraph() }
        }
        .navigationDestination(for: WikiPage.self) { destination in
            PageDetailView(page: destination)
        }
    }
    
    private var insightsPanel: some View {
        NavigationStack {
            GraphInsightsPanel(
                surprising: insightSurprising,
                orphans: insightOrphans,
                sparse: insightSparse,
                bridges: insightBridges,
                nodes: nodes,
                onSelectNode: { nodeID in
                    selectedNodeID = nodeID
                    isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isAnimating = false }
                    showInsights = false
                }
            )
            .navigationTitle(Localized.tr("graph.insights"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localized.tr("misc.cancel")) {
                        showInsights = false
                    }
                }
            }
        }
    }
    
    private var graphToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                // 左侧统计文字，增加起始间距
                Text(Localized.trf("graph.nodesConnections", getFilteredNodes().count, getFilteredEdges(for: getFilteredNodes()).count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.wikiSecondary)
                    .padding(.leading, 8)
                
                HStack(spacing: 12) {
                    // 洞察灯泡 (仅保留最核心的图谱洞察功能)
                    Button(action: { 
                        computeInsights()
                        showInsights = true 
                    }) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.wikiAccent)
                    }
                    .help(Localized.tr("graph.insights"))
                }
                .font(.system(size: 13))
                .foregroundStyle(.wikiAccent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.wikiCard.opacity(0.8))
                    .overlay(Capsule().stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1))
            }
        }
    }
    
    private func computeInsights() {
        let (surprising, orphans, sparse, bridges) = GraphLayoutEngine.detectInsights(
            nodes: nodes,
            edges: edges,
            pages: store.pages
        )
        insightSurprising = surprising
        insightOrphans = orphans
        insightSparse = sparse
        insightBridges = bridges
    }

    private func layoutGraph() {
        let result = GraphLayoutEngine.layout(
            pages: store.pages,
            linkResolver: { title in store.pages.first(where: { $0.title == title }) },
            canvasSize: graphSize
        )
        nodes = result.nodes
        edges = result.edges
    }
}

// MARK: - Graph Canvas View
struct GraphCanvasView: View {
    let filteredNodes: [GraphNode]
    let filteredEdges: [GraphEdge]
    let clusters: [GraphClusteringService.Cluster]
    let useClustering: Bool
    @Binding var selectedNodeID: UUID?
    @Binding var isAnimating: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var graphSize: CGSize
    let onNodeTap: (GraphNode) -> Void

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let _ = updatePhysics(at: timeline.date)
                
                ZStack {
                    // 渲染边
                    Canvas { context, size in
                        drawEdges(in: context, size: size)
                    }
                    .frame(width: max(geometry.size.width, graphSize.width),
                           height: max(geometry.size.height, graphSize.height))

                    // 渲染节点
                    ForEach(filteredNodes) { node in
                        renderNode(node, in: geometry)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(zoomGesture)
                .simultaneousGesture(dragGesture)
                .onAppear { 
                    if graphSize.width == 0 { graphSize = geometry.size }
                }
            }
        }
    }
    
    private func drawEdges(in context: GraphicsContext, size: CGSize) {
        for edge in filteredEdges {
            guard let sourceNode = filteredNodes.first(where: { $0.id == edge.source }),
                  let targetNode = filteredNodes.first(where: { $0.id == edge.target }) else { continue }

            var path = Path()
            path.move(to: sourceNode.position)
            path.addLine(to: targetNode.position)

            let isSelected = selectedNodeID == edge.source || selectedNodeID == edge.target
            let color = isSelected ? Color.wikiAccent : Color.wikiBorder.opacity(0.35)
            let width: CGFloat = isSelected ? 2.5 : 1.0
            
            context.stroke(path, with: .color(color), lineWidth: width)
        }
    }
    
    private func renderNode(_ node: GraphNode, in geometry: GeometryProxy) -> some View {
        let isSelected = selectedNodeID == node.id
        let linkCount = filteredEdges.filter { $0.source == node.id || $0.target == node.id }.count
        
        return Group {
            GraphNodeView(
                node: node,
                isSelected: isSelected,
                isAnimating: isAnimating,
                linkCount: linkCount,
                clusters: clusters,
                useClustering: useClustering,
                onSelect: { onNodeTap(node) },
                viewportRect: geometry.frame(in: .local),
                scale: scale
            )
            
            let baseSize: CGFloat = 20
            let nodeSize = isSelected ? 40 : max(24, min(40, baseSize + CGFloat(linkCount) * 3))
            GraphNodeLabel(node: node, isSelected: isSelected, nodeSize: nodeSize)
        }
    }
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 0.5), 4.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let newWidth = lastOffset.width + value.translation.width
                let newHeight = lastOffset.height + value.translation.height
                // 限制拖拽范围，防止将图谱拖出可视区域
                let maxDrag = max(graphSize.width, graphSize.height) * scale
                offset = CGSize(
                    width: min(max(newWidth, -maxDrag), maxDrag),
                    height: min(max(newHeight, -maxDrag), maxDrag)
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private func updatePhysics(at date: Date) -> Bool {
        guard isAnimating else { return false }
        var currentNodes = filteredNodes
        GraphLayoutEngine.applyForces(
            nodes: &currentNodes,
            edges: filteredEdges,
            canvasWidth: graphSize.width,
            canvasHeight: graphSize.height,
            config: .default,
            temperature: 0.1
        )
        return true
    }
}

// MARK: - Subviews
private struct GraphEmptyStateView: View {
    @EnvironmentObject var store: KMStore
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // 背景光晕
                Circle()
                    .fill(Color.wikiAccent.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)
                
                // 核心插画 (使用生成的素材)
                Image("knowledge_graph_empty_state_1777692727826")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(
                                LinearGradient(colors: [.wikiAccent.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                Text(Localized.tr("graph.emptyTitle"))
                    .font(.title2.bold())
                    .foregroundStyle(.wikiText)
                
                Text(Localized.tr("graph.emptyDesc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: {
                // 切换到导入 Tab
                // 假设 TabView 绑定在 ContentView 的 selectedTab
                // 我们可以通过通知或 store 状态来切换
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToIngestTab"), object: nil)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(Localized.tr("graph.startBuilding"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [.wikiAccent, .wikiSource], startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: .wikiAccent.opacity(0.4), radius: 10, y: 5)
            }
            
            Text(Localized.tr("graph.tip.biLink"))
                .font(.caption2)
                .foregroundStyle(.wikiBorder)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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

private struct GraphFilterPillsView: View {
    @Binding var filterType: PageType?
    @ObservedObject var tooltipManager: TooltipManager

    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterPill(title: Localized.tr("search.all"), isSelected: filterType == nil) {
                        filterType = nil
                    }
                    ForEach(PageType.allCases) { type in
                        FilterPill(title: type.displayName, icon: type.icon, color: type.themedColor, isSelected: filterType == type) {
                            filterType = type
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            Spacer()
        }
    }
}

private struct GraphLegendView: View {
    let useClustering: Bool
    let clusters: [GraphClusteringService.Cluster]
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                GraphLegend(useClustering: useClustering, clusters: clusters)
                    .padding(.trailing, 16)
            }
            .padding(.top, 50)
            Spacer()
        }
    }
}
