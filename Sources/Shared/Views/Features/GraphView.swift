// GraphView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的核心可视化引擎——知识图谱视图（GraphView），通过交互式拓扑图展示知识点间的关联结构。
// 视图集成了基于力导向算法的物理布局引擎，通过以下功能点实现了大规模知识内容的直觉化导航：
// 1. 交互式拓扑探索：支持节点的拖拽、缩放（Zoom）及自动对齐（Fit to Screen），并内置了针对不同缩放等级的细节分级加载（LOD）技术。
// 2. 深度关系分析：提供孤儿节点识别、关联桥梁检测及高频核心概念提取等洞察功能，辅助用户发现知识体系中的薄弱环节。
// 3. 语义化视觉渲染：基于节点类型自动匹配主题色彩，并支持通过聚类算法（Clustering）展示知识领域的边界与重合。
// 4. 多维呈现模式：除了 2D 拓扑布局外，还集成了 3D 沉浸式图谱模式，为用户提供空间化的知识感知维度。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，系统性清理图谱交互内部的魔鬼数字与物理常数
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Graph Container View
/// 知识图谱可视化容器视图入口
struct GraphContainerView: View {
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    var heroNamespace: Namespace.ID
    @Binding var selectedTab: AppTab
    @State private var viewModel = GraphViewModel()
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        let currentFilteredNodes = viewModel.getFilteredNodes()
        let currentFilteredEdges = viewModel.getFilteredEdges(for: currentFilteredNodes)

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
            .contentShape(Rectangle())
            .onTapGesture {
                // 点击空白处取消选中，从而隐藏详情卡片
                withAnimation(.spring(response: 0.4)) {
                    viewModel.selectedNodeID = nil
                    viewModel.isAnimating = false
                }
            }

            if viewModel.nodes.isEmpty {
                GraphEmptyStateView(selectedTab: $selectedTab)
            } else {
                GraphCanvasView(
                    nodes: $viewModel.nodes,
                    filteredEdges: currentFilteredEdges,
                    provider: store,
                    filterType: viewModel.filterType,
                    useClustering: viewModel.useClustering,
                    selectedNodeID: $viewModel.selectedNodeID,
                    isAnimating: $viewModel.isAnimating,
                    scale: $viewModel.scale,
                    lastScale: $viewModel.lastScale,
                    offset: $viewModel.offset,
                    lastOffset: $viewModel.lastOffset,
                    graphSize: $viewModel.graphSize,
                    heroNamespace: heroNamespace
                ) { node in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        if viewModel.selectedNodeID == node.id {
                            viewModel.selectedNodeID = nil
                            viewModel.isAnimating = false
                        } else {
                            viewModel.selectedNodeID = node.id
                            viewModel.isAnimating = true

                            // 自动聚焦逻辑
                            // 目标：将节点平移至视口中心
                            // 注意：由于 Canvas 可能很大且应用了 scale 和 offset，
                            // 我们需要计算抵消节点当前坐标的位移。
                            let targetOffsetX = -node.position.x * viewModel.scale
                            let targetOffsetY = -node.position.y * viewModel.scale

                            // 加上屏幕中心补偿
                            viewModel.offset = CGSize(
                                width: targetOffsetX + viewModel.graphSize.width / 2,
                                height: targetOffsetY + viewModel.graphSize.height / 2
                            )
                            viewModel.lastOffset = viewModel.offset

                            // 如果当前缩放太小，自动放大至 1.2 倍以看清细节
                            if viewModel.scale < 1.0 {
                                viewModel.scale = 1.2
                                viewModel.lastScale = 1.2
                            }
                            
                            // 性能稳定逻辑：持续物理模拟以达到稳定平衡
                            Task {
                                try? await Task.sleep(for: .seconds(WikiUI.Graph.physicsStableDuration))
                                await MainActor.run {
                                    viewModel.isAnimating = false
                                }
                            }
                        }
                    }
                    HapticFeedback.shared.trigger(.selection)
                }
                // 顶部控件区域
                VStack(alignment: .leading, spacing: 8) {
                    graphStatsBar
                        .padding(.leading, 16)
                        .padding(.top, 8)

                    GraphFilterPillsView(
                        filterType: $viewModel.filterType,
                        tooltipManager: tooltipManager
                    )

                    Spacer()
                }
                
                // ══ 绘图区域边框 (Drawing Boundary) ══
                // 确保绘图内容不会溢出到侧边栏或不安全区域
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.wikiAccent.opacity(0.3), Color.wikiAccent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .clipped() // 强制剪裁，防止 Canvas  spill-over
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.nodes.isEmpty {
                GraphZoomControls(
                    scale: $viewModel.scale,
                    lastScale: $viewModel.lastScale,
                    offset: $viewModel.offset,
                    lastOffset: $viewModel.lastOffset,
                    show3D: $viewModel.show3D,
                    onRelayout: layoutGraph,
                    onFitToScreen: fitToScreen
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.trailing, 16)
                .padding(.bottom, viewModel.selectedNodeID != nil ? 140 : 16)
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.nodes.isEmpty, let selectedID = viewModel.selectedNodeID,
               let page = store.pages.first(where: { $0.id == selectedID }) {
                GraphSelectedNodeCard(page: page)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !viewModel.nodes.isEmpty, viewModel.showLegend {
                GraphLegendView(useClustering: viewModel.useClustering, clusters: store.clusters)
                    .padding(.trailing, 16)
                    .padding(.top, 100)
            }
        }
        .navigationTitle(L10n.Graph.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { layoutGraph() }
        .onChange(of: store.pages.count) { _, _ in
            withAnimation(.spring(response: 0.6)) { layoutGraph() }
        }
        .navigationDestination(for: AppRoute.self) { route in
            ViewFactory.makeView(for: route)
        }
        .sheet(isPresented: $viewModel.showInsights) {
            insightsPanel
        }
        .fullScreenCover(isPresented: $viewModel.show3D) {
            Graph3DView(
                selectedNodeID: $viewModel.selectedNodeID,
                isFullScreen: Binding(
                    get: { true },
                    set: { if !$0 { viewModel.show3D = false } }
                )
            )
        }
        .overlay {
            if viewModel.isLayouting {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.wikiAccent)
                    Text(L10n.Graph.optimizingLayout)
                        .font(.caption.bold())
                        .foregroundStyle(.wikiAccent)
                }
                .padding(WikiUI.large)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.large))
                .shadow(color: .black.opacity(0.1), radius: WikiUI.medium)
            }
        }
    }
    
    private var insightsPanel: some View {
        NavigationStack {
            GraphInsightsPanel(
                surprising: viewModel.insightSurprising,
                orphans: viewModel.insightOrphans,
                sparse: viewModel.insightSparse,
                bridges: viewModel.insightBridges,
                nodes: viewModel.nodes,
                onSelectNode: { nodeID in
                    viewModel.selectedNodeID = nodeID
                    viewModel.isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { viewModel.isAnimating = false }
                    viewModel.showInsights = false
                }
            )
            .navigationTitle(L10n.Graph.tr("insights"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("cancel")) {
                        viewModel.showInsights = false
                    }
                }
            }
        }
    }
    
    private var graphStatsBar: some View {
        HStack(spacing: 10) {
            // 统计文字
            Text(L10n.Graph.trf("nodesConnections", viewModel.getFilteredNodes().count, viewModel.getFilteredEdges(for: viewModel.getFilteredNodes()).count))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.wikiSecondary)
                .padding(.leading, 4)
            
            Divider()
                .frame(height: 12)
                .foregroundStyle(.wikiBorder)

            // 洞察灯泡
            Button(action: {
                computeInsights()
                viewModel.showInsights = true
            }) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.wikiAccent)
            }
            .help(L10n.Graph.tr("insights"))
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
        let (surprising, orphans, sparse, bridges) = GraphLayoutProcessor.detectInsights(
            nodes: viewModel.nodes,
            edges: viewModel.edges,
            pages: store.pages
        )
        viewModel.insightSurprising = surprising
        viewModel.insightOrphans = orphans
        viewModel.insightSparse = sparse
        viewModel.insightBridges = bridges
    }

    private func layoutGraph() {
        let pages = store.pages
        let canvasSize = viewModel.graphSize
        
        // 如果没有数据，直接清空并返回，避免显示加载遮罩导致卡死
        guard !pages.isEmpty else {
            viewModel.nodes = []
            viewModel.edges = []
            viewModel.isLayouting = false
            viewModel.isAnimating = false
            return
        }
        
        viewModel.isLayouting = true
        
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                GraphLayoutProcessor.layout(
                    pages: pages,
                    linkResolver: { title in pages.first(where: { $0.title == title }) },
                    canvasSize: canvasSize
                )
            }.value
            
            await MainActor.run {
                viewModel.isLayouting = false
                withAnimation(.spring(response: 0.8)) {
                    viewModel.nodes = result.nodes
                    viewModel.edges = result.edges
                }
                fitToScreen()
                
                // 布局完成后持续模拟一小段时间以达到稳定平衡
                viewModel.isAnimating = true
                Task {
                    try? await Task.sleep(for: .seconds(WikiUI.Graph.physicsStableDuration))
                    await MainActor.run {
                        viewModel.isAnimating = false
                    }
                }
            }
        }
    }

    private func fitToScreen() {
        guard !viewModel.nodes.isEmpty else { return }

        // 计算所有节点的包围盒
        let minX = viewModel.nodes.map { $0.position.x }.min() ?? 0
        let maxX = viewModel.nodes.map { $0.position.x }.max() ?? viewModel.graphSize.width
        let minY = viewModel.nodes.map { $0.position.y }.min() ?? 0
        let maxY = viewModel.nodes.map { $0.position.y }.max() ?? viewModel.graphSize.height

        let contentWidth = maxX - minX
        let contentHeight = maxY - minY

        // 留出一定的边距 (padding)
        let padding: CGFloat = 60
        let availableWidth = viewModel.graphSize.width - padding * 2
        let availableHeight = viewModel.graphSize.height - padding * 2

        // 计算缩放比例
        let scaleX = availableWidth / max(contentWidth, 100)
        let scaleY = availableHeight / max(contentHeight, 100)
        let targetScale = min(max(min(scaleX, scaleY), 0.5), 2.0)

        // 计算偏移量，使图谱中心对齐画布中心
        let contentCenterX = (minX + maxX) / 2
        let contentCenterY = (minY + maxY) / 2
        let targetOffsetX = (viewModel.graphSize.width / 2 - contentCenterX) * targetScale
        let targetOffsetY = (viewModel.graphSize.height / 2 - contentCenterY) * targetScale

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            viewModel.scale = targetScale
            viewModel.lastScale = targetScale
            viewModel.offset = CGSize(width: targetOffsetX, height: targetOffsetY)
            viewModel.lastOffset = viewModel.offset
        }
    }
}

// MARK: - Graph Canvas View
struct GraphCanvasView: View {
    @Binding var nodes: [GraphNode]
    let filteredEdges: [GraphEdge]
    let provider: any GraphDataProvider
    let filterType: PageType?
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
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                let _ = updatePhysics(at: timeline.date)
                
                // 渲染节点逻辑
                let currentFilteredNodes = nodes.filter { node in
                    guard let filter = filterType else { return true }
                    return node.type == filter
                }
                
                ZStack {
                    // 渲染边
                    Canvas { context, size in
                        drawEdges(in: context, size: size)
                    }
                    .frame(width: max(geometry.size.width, graphSize.width),
                           height: max(geometry.size.height, graphSize.height))

                    // 优化：仅在选中节点时计算邻居 ID
                    let neighborIDs: Set<UUID> = {
                        guard let selectedID = selectedNodeID else { return [] }
                        return Set(filteredEdges.compactMap { edge in
                            if edge.source == selectedID { return edge.target }
                            if edge.target == selectedID { return edge.source }
                            return nil
                        })
                    }()
                    
                    ForEach(currentFilteredNodes) { node in
                        let isSelected = selectedNodeID == node.id
                        let isNeighbor = neighborIDs.contains(node.id)
                        let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
                        
                        renderNode(node, isSelected: isSelected, isNeighbor: isNeighbor, isDimmed: isDimmed, in: geometry)
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
                .accessibilityLabel(L10n.Graph.tr("accessibility.canvasLabel"))
                .accessibilityValue(L10n.Graph.trf("nodesConnections", currentFilteredNodes.count, filteredEdges.count))
                .accessibilityHint(L10n.Graph.tr("accessibility.canvasHint"))
            }
        }
    }
    
    private func getNodeSize(for node: GraphNode) -> CGFloat {
        let isSelected = selectedNodeID == node.id
        let linkCount = filteredEdges.filter { $0.source == node.id || $0.target == node.id }.count
        let baseSize = WikiUI.Graph.defaultNodeSize
        return isSelected ? WikiUI.Graph.selectedNodeSize : max(baseSize, min(WikiUI.Graph.selectedNodeSize, baseSize + CGFloat(linkCount) * 3))
    }

    private func drawEdges(in context: GraphicsContext, size: CGSize) {
        // LOD: 远景模式下降低连线亮度
        let baseOpacity: Double = scale < 0.8 ? 0.15 : 0.35
        
        // 优化：使用字典建立快速查找索引 (O(N))
        let nodeLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        
        for edge in filteredEdges {
            guard let sourceNode = nodeLookup[edge.source],
                  let targetNode = nodeLookup[edge.target] else { continue }
            
            // 额外的过滤检查：如果当前设置了类型过滤，确保两端节点都符合条件
            if let filter = filterType {
                guard sourceNode.type == filter && targetNode.type == filter else { continue }
            }

            let sPos = sourceNode.position
            let tPos = targetNode.position
            
            // 计算节点半径，使连线只连到圆圈边缘而非中心图标
            let sRadius = getNodeSize(for: sourceNode) / 2
            let tRadius = getNodeSize(for: targetNode) / 2
            
            // 计算方向向量和距离
            let dx = tPos.x - sPos.x
            let dy = tPos.y - sPos.y
            let distance = hypot(dx, dy)
            
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
                // 选中状态：使用高亮渐变色，并增加线宽
                let gradient = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [sourceNode.type.themedColor, targetNode.type.themedColor]),
                    startPoint: CGPoint(x: startX, y: startY),
                    endPoint: CGPoint(x: endX, y: endY)
                )
                context.stroke(path, with: gradient, lineWidth: 3.0)
            } else {
                // 普通状态：如果有选中点但当前连线不是关联线，则大幅调暗
                let isAnySelected = selectedNodeID != nil
                let opacity = isAnySelected ? 0.05 : baseOpacity
                let color = Color.wikiBorder.opacity(opacity)
                context.stroke(path, with: .color(color), lineWidth: 1.0)
            }
        }
    }
    
    private func renderNode(_ node: GraphNode, isSelected: Bool, isNeighbor: Bool, isDimmed: Bool, in geometry: GeometryProxy) -> some View {
        let linkCount = node.linkCount
        
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
                viewportRect: CGRect(origin: CGPoint(x: -offset.width / scale, y: -offset.height / scale), size: CGSize(width: geometry.size.width / scale, height: geometry.size.height / scale)),
                scale: scale
            )
            .opacity(isDimmed ? 0.2 : 1.0)
            .animation(.easeInOut, value: isDimmed)
            
            let nodeSize = getNodeSize(for: node)
            let isLowDetail = scale < 0.8
            
            if isSelected || isNeighbor || !isLowDetail {
                GraphNodeLabel(node: node, isSelected: isSelected, nodeSize: nodeSize)
            }
        }
    }
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, WikiUI.Graph.minScale), WikiUI.Graph.maxScale)
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
        // 核心修复：如果节点为空或未开启仿真，立即退出，防止无效计算占用主线程
        guard isAnimating && !nodes.isEmpty else { return false }
        
        // 性能优化：节点过多时，降低物理模拟的复杂度
        let iterationTemp: CGFloat = nodes.count > 500 ? 0.02 : 0.1
        
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: filteredEdges,
            canvasWidth: graphSize.width,
            canvasHeight: graphSize.height,
            config: .default,
            temperature: iterationTemp
        )
        return true
    }
}

// MARK: - Subviews
private struct GraphEmptyStateView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: AppTab
    
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
                Text(L10n.Graph.tr("emptyTitle"))
                    .font(.title2.bold())
                    .foregroundStyle(.wikiText)
                
                Text(L10n.Graph.tr("emptyDesc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(0.8)
            }

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
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
                    Text(L10n.Graph.tr("startBuilding"))
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
            
            Text(L10n.Graph.tr("tip.biLink"))
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
    @Binding var show3D: Bool
    let onRelayout: () -> Void
    let onFitToScreen: () -> Void

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
                    show3D: $show3D,
                    onRelayout: onRelayout,
                    onFitToScreen: onFitToScreen
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
