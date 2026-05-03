import SwiftUI

/// 图形可视化容器视图
struct GraphContainerView: View {
    @Environment(KMStore.self) var store
    var heroNamespace: Namespace.ID
    @Binding var selectedTab: ContentView.AppTab
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
    @State private var show3D = false
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
            // 3D 图谱同款渐变底色
            ZStack {
                Color.wikiBackground

                LinearGradient(
                    colors: [
                        Color.wikiAccent.opacity(0.12),
                        Color.wikiAccent.opacity(0.04),
                        Color.clear,
                        Color.wikiAccent.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 50)

                RadialGradient(
                    gradient: Gradient(colors: [Color.wikiAccent.opacity(0.08), Color.clear]),
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()

            if nodes.isEmpty {
                GraphEmptyStateView(selectedTab: $selectedTab)
            } else {
                GraphCanvasView(
                    filteredNodes: currentFilteredNodes,
                    filteredEdges: currentFilteredEdges,
                    provider: store,
                    useClustering: useClustering,
                    selectedNodeID: $selectedNodeID,
                    isAnimating: $isAnimating,
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset,
                    graphSize: $graphSize,
                    heroNamespace: heroNamespace
                ) { node in
                    withAnimation(.spring(response: 0.5)) {
                        selectedNodeID = selectedNodeID == node.id ? nil : node.id
                        isAnimating = selectedNodeID != nil
                    }
                }

                // 顶部控件区域
                VStack(alignment: .leading, spacing: 8) {
                    graphStatsBar
                        .padding(.leading, 16)
                        .padding(.top, 8)

                    GraphFilterPillsView(
                        filterType: $filterType,
                        tooltipManager: tooltipManager
                    )

                    Spacer()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !nodes.isEmpty {
                // 右下角统一控制组
                HStack(spacing: 0) {
                    GraphZoomControls(
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        onRelayout: layoutGraph
                    )

                    Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

                    Button(action: { show3D = true }) {
                        Image(systemName: "view.3d")
                            .font(.body)
                            .foregroundStyle(.wikiAccent)
                            .frame(width: 36, height: 36)
                            .background(Color.wikiCard)
                    }
                    .accessibilityIdentifier("graph-3d")
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.trailing, 16)
                .padding(.bottom, selectedNodeID != nil ? 140 : 16)
            }
        }
        .overlay(alignment: .bottom) {
            if !nodes.isEmpty, let selectedID = selectedNodeID,
               let page = store.pages.first(where: { $0.id == selectedID }) {
                GraphSelectedNodeCard(page: page)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !nodes.isEmpty, showLegend {
                GraphLegendView(useClustering: useClustering, clusters: store.clusters)
                    .padding(.trailing, 16)
                    .padding(.top, 100)
            }
        }
        .navigationTitle(Localized.tr("graph.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { layoutGraph() }
        .onChange(of: store.pages.count) { _, _ in
            withAnimation(.spring(response: 0.6)) { layoutGraph() }
        }
        .navigationDestination(for: WikiPage.self) { destination in
            PageDetailView(page: destination)
        }
        .sheet(isPresented: $showInsights) {
            insightsPanel
        }
        .fullScreenCover(isPresented: $show3D) {
            Graph3DView(
                selectedNodeID: $selectedNodeID,
                isFullScreen: Binding(
                    get: { true },
                    set: { if !$0 { show3D = false } }
                )
            )
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
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.cancel")) {
                        showInsights = false
                    }
                }
            }
        }
    }
    
    private var graphStatsBar: some View {
        HStack(spacing: 10) {
            // 统计文字
            Text(Localized.trf("graph.nodesConnections", getFilteredNodes().count, getFilteredEdges(for: getFilteredNodes()).count))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.wikiSecondary)
                .padding(.leading, 4)
            
            Divider()
                .frame(height: 12)
                .foregroundStyle(.wikiBorder)

            // 洞察灯泡
            Button(action: { 
                computeInsights()
                showInsights = true 
            }) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.wikiAccent)
            }
            .help(Localized.tr("graph.insights"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color.wikiCard.opacity(0.85))
                .overlay(Capsule().stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1))
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
    let provider: any GraphDataProvider
    let useClustering: Bool
    @Binding var selectedNodeID: UUID?
    @Binding var isAnimating: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var graphSize: CGSize
    var heroNamespace: Namespace.ID
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
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Localized.tr("graph.accessibility.canvasLabel"))
                .accessibilityValue(Localized.trf("graph.nodesConnections", filteredNodes.count, filteredEdges.count))
                .accessibilityHint(Localized.tr("graph.accessibility.canvasHint"))
            }
        }
    }
    
    private func getNodeSize(for node: GraphNode) -> CGFloat {
        let isSelected = selectedNodeID == node.id
        let linkCount = filteredEdges.filter { $0.source == node.id || $0.target == node.id }.count
        let baseSize: CGFloat = 20
        return isSelected ? 40 : max(24, min(40, baseSize + CGFloat(linkCount) * 3))
    }

    private func drawEdges(in context: GraphicsContext, size: CGSize) {
        // LOD: 远景模式下降低连线亮度
        let baseOpacity: Double = scale < 0.8 ? 0.15 : 0.35
        
        for edge in filteredEdges {
            guard let sourceNode = filteredNodes.first(where: { $0.id == edge.source }),
                  let targetNode = filteredNodes.first(where: { $0.id == edge.target }) else { continue }

            let sPos = sourceNode.position
            let tPos = targetNode.position
            
            // 计算节点半径，使连线只连到圆圈边缘而非中心图标
            let sRadius = getNodeSize(for: sourceNode) / 2
            let tRadius = getNodeSize(for: targetNode) / 2
            
            // 计算方向向量和距离
            let dx = tPos.x - sPos.x
            let dy = tPos.y - sPos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // 如果节点重合，跳过
            if distance < (sRadius + tRadius) { continue }
            
            // 计算缩进后的起点和终点
            let startX = sPos.x + dx * (sRadius / distance)
            let startY = sPos.y + dy * (sRadius / distance)
            let endX = tPos.x - dx * (tRadius / distance)
            let endY = tPos.y - dy * (tRadius / distance)
            
            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let isHighlighted = selectedNodeID == edge.source || selectedNodeID == edge.target
            
            if isHighlighted {
                // 选中状态：使用高亮渐变色
                let gradient = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [sourceNode.type.themedColor, targetNode.type.themedColor]),
                    startPoint: CGPoint(x: startX, y: startY),
                    endPoint: CGPoint(x: endX, y: endY)
                )
                context.stroke(path, with: gradient, lineWidth: 2.5)
            } else {
                // 普通状态：弱化的自适应色
                let color = Color.wikiBorder.opacity(baseOpacity)
                context.stroke(path, with: .color(color), lineWidth: 1.0)
            }
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
                clusters: provider.clusters,
                useClustering: useClustering,
                onSelect: { onNodeTap(node) },
                heroNamespace: heroNamespace,
                viewportRect: geometry.frame(in: .local),
                scale: scale
            )
            
            let nodeSize = getNodeSize(for: node)
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
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    
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
                    .opacity(0.8)
            }

            Button(action: {
                HapticManager.shared.trigger(.selection)
                // 方案 A：跳转到 Wiki 并自动唤起新建页面表单
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = .wiki
                    }
                    // 延迟一瞬确保 Tab 切换完成后再弹出 Sheet，避免视觉冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        store.showCreateSheet = true
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(Localized.tr("graph.startBuilding"))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [Color.wikiAccent, Color.wikiSource], startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Color.wikiAccent.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(PlainButtonStyle()) // 防止全局按钮样式干扰
            
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
            .padding(.top, 100)
        }
    }
}

private struct GraphFilterPillsView: View {
    @Binding var filterType: PageType?
    @ObservedObject var tooltipManager: TooltipManager

    var body: some View {
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
