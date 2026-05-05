// GraphView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的核心可视化引擎——知识图谱视图（GraphView）。
// 版本: 1.4
// 修改记录:
//   - 2026-05-05: 修复容器边框布局层次，将分类过滤器移出边框。
//   - 2026-05-05: 修复内容溢出问题，增加画布裁剪逻辑。
//   - 2026-05-05: 恢复连线高亮逻辑、避让算法及交互反馈。
//   - 2026-05-05: 优化边框颜色，修复点击空白消失卡片及按钮联动逻辑。
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 图谱容器
@MainActor
/// 知识图谱顶层容器
/// 负责管理图谱画布、统计信息、过滤器及详情卡片的组合布局
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
            // 1. 底层背景与点击取消逻辑
            ZStack {
                Color.wikiBackground
                LinearGradient(
                    colors: [Color.wikiAccent.opacity(0.12), Color.wikiAccent.opacity(0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).blur(radius: 50)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                dismissCard()
            }

            if viewModel.nodes.isEmpty {
                GraphEmptyStateView(selectedTab: $selectedTab)
            } else {
                // 2. 主体布局：标题/过滤项 + 画布
                VStack(spacing: 12) {
                    // 顶部非描边区域：统计与过滤器
                    VStack(alignment: .leading, spacing: 12) {
                        graphStatsBar
                        
                        GraphFilterPillsView(
                            filterType: $viewModel.filterType,
                            tooltipManager: tooltipManager
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .zIndex(10) // 确保在画布之上

                    // 核心绘图区：应用柔和边框与裁剪
                    ZStack {
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
                            handleNodeTap(node)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissCard()
                        }
                    }
                    .background(WikiUI.containerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                            .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle(L10n.Graph.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { layoutGraph() }
        .onChange(of: store.pages.count) { _, _ in layoutGraph() }
        .sheet(isPresented: $viewModel.showInsights) { insightsPanel }
        .fullScreenCover(isPresented: $viewModel.show3D) {
            Graph3DView(selectedNodeID: $viewModel.selectedNodeID, isFullScreen: $viewModel.show3D)
        }
        .overlay(alignment: .bottomTrailing) {
            // 3. 动态联动的缩放工具栏
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
                .overlay(RoundedRectangle(cornerRadius: WikiUI.standardRadius).stroke(Color.wikiBorder.opacity(0.5), lineWidth: 0.5))
                .padding(.trailing, 24)
                .padding(.bottom, viewModel.selectedNodeID != nil ? 110 : 32) // 联动上移，减小与下方详情卡片的间距 (从130下调至110)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedNodeID)
            }
        }
        .overlay(alignment: .bottom) {
            // 4. 详情卡片
            if let selectedID = viewModel.selectedNodeID,
               let page = store.pages.first(where: { $0.id == selectedID }) {
                GraphSelectedNodeCard(page: page)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /**
     * @description: 关闭当前选中的节点详情卡片并停止高亮动画
     * @return {*}
     */
    private func dismissCard() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.selectedNodeID = nil
            viewModel.isAnimating = false
        }
    }

    /**
     * @description: 处理节点点击事件：切换选中状态、相机自动聚焦定位、触发震动反馈
     * @param {GraphNode} node 被点击的节点对象
     * @return {*}
     */
    private func handleNodeTap(_ node: GraphNode) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            if viewModel.selectedNodeID == node.id {
                viewModel.selectedNodeID = nil
                viewModel.isAnimating = false
            } else {
                viewModel.selectedNodeID = node.id
                viewModel.isAnimating = true
                
                // 聚焦逻辑：计算偏移量使节点居中
                let targetOffsetX = -node.position.x * viewModel.scale
                let targetOffsetY = -node.position.y * viewModel.scale
                viewModel.offset = CGSize(
                    width: targetOffsetX + viewModel.graphSize.width / 2,
                    height: targetOffsetY + viewModel.graphSize.height / 2
                )
                viewModel.lastOffset = viewModel.offset
                if viewModel.scale < 1.0 { viewModel.scale = 1.2; viewModel.lastScale = 1.2 }
            }
        }
        HapticFeedback.shared.trigger(.selection)
    }

    /**
     * @description: 渲染图谱顶部的统计信息栏与洞察分析入口
     * @return {View}
     */
    private var graphStatsBar: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            computeInsights()
            viewModel.showInsights = true
        }) {
            HStack(spacing: 12) {
                Text(L10n.Graph.trf("nodesConnections", viewModel.getFilteredNodes().count, viewModel.getFilteredEdges(for: viewModel.getFilteredNodes()).count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.wikiSecondary)
                
                Divider().frame(height: 12)
                
                Image(systemName: "eye.fill") // 洞察图标
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.wikiAccent))
                    .shadow(color: Color.wikiAccent.opacity(0.3), radius: 4)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.wikiCard.opacity(0.95)))
            .overlay(Capsule().stroke(Color.wikiBorder.opacity(0.5), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    /**
     * @description: 调用 GraphLayoutProcessor 计算知识图谱的发现与洞察信息
     * @return {*}
     */
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

    /**
     * @description: 执行核心布局算法：将 WikiPages 转换为 GraphNodes 与 Edges，并应用自适应缩放
     * @return {*}
     */
    private func layoutGraph() {
        let pages = store.pages
        // 核心修复：如果数据为空，必须清空视图模型，否则旧数据会残留
        if pages.isEmpty {
            viewModel.nodes = []
            viewModel.edges = []
            viewModel.isLayouting = false
            return
        }

        viewModel.isLayouting = true
        Task {
            let canvasSize = viewModel.graphSize
            let result = await Task.detached {
                return GraphLayoutProcessor.layout(
                    pages: pages,
                    linkResolver: { t in pages.first(where: { $0.title == t }) },
                    canvasSize: canvasSize
                )
            }.value
            await MainActor.run {
                viewModel.nodes = result.nodes
                viewModel.edges = result.edges
                viewModel.isLayouting = false
                fitToScreen()
            }
        }
    }

    /**
     * @description: 计算最佳缩放比例与偏移量，使所有节点完整展示在屏幕视野内
     * @return {*}
     */
    private func fitToScreen() {
        guard !viewModel.nodes.isEmpty else { return }
        let minX = viewModel.nodes.map(\.position.x).min() ?? 0
        let maxX = viewModel.nodes.map(\.position.x).max() ?? 0
        let minY = viewModel.nodes.map(\.position.y).min() ?? 0
        let maxY = viewModel.nodes.map(\.position.y).max() ?? 0
        let padding: CGFloat = 60
        let scaleX = (viewModel.graphSize.width - padding * 2) / max(maxX - minX, 100)
        let scaleY = (viewModel.graphSize.height - padding * 2) / max(maxY - minY, 100)
        let targetScale = min(max(min(scaleX, scaleY), 0.5), 2.0)
        let targetOffsetX = (viewModel.graphSize.width / 2 - (minX + maxX) / 2) * targetScale
        let targetOffsetY = (viewModel.graphSize.height / 2 - (minY + maxY) / 2) * targetScale
        withAnimation(.spring()) {
            viewModel.scale = targetScale
            viewModel.offset = CGSize(width: targetOffsetX, height: targetOffsetY)
            viewModel.lastScale = targetScale
            viewModel.lastOffset = viewModel.offset
        }
    }
    
    /**
     * @description: 渲染图谱洞察侧边面板
     * @return {View}
     */
    private var insightsPanel: some View {
        NavigationStack {
            GraphInsightsPanel(
                surprising: viewModel.insightSurprising,
                orphans: viewModel.insightOrphans,
                sparse: viewModel.insightSparse,
                bridges: viewModel.insightBridges,
                nodes: viewModel.nodes,
                onSelectNode: { nodeID in
                    if let node = viewModel.nodes.first(where: { $0.id == nodeID }) {
                        handleNodeTap(node)
                    }
                    viewModel.showInsights = false
                }
            )
            .navigationTitle(L10n.Graph.tr("insights"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.tr("cancel")) { viewModel.showInsights = false }
                }
            }
        }
    }
}

// MARK: - 图谱画布视图
/// 知识图谱画布视图
/// 负责 2D 环境下的节点渲染、连线绘制及平移/缩放手法交互处理
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
            ZStack {
                // 渲染边
                Canvas { context, size in
                    drawEdges(in: context, size: size)
                }
                .frame(width: max(geometry.size.width, graphSize.width), height: max(geometry.size.height, graphSize.height))

                // 渲染节点
                let isLowDetail = scale < AppConfig.UI.graphLODZoomThreshold
                
                ForEach(nodes.filter { filterType == nil || $0.type == filterType }) { node in
                    renderNode(node)
                    
                    if !isLowDetail {
                        GraphNodeLabel(
                            node: node,
                            isSelected: selectedNodeID == node.id,
                            nodeSize: 20 // 减小字体参考尺寸
                        )
                    }
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(zoomGesture)
            .simultaneousGesture(dragGesture)
            .onAppear { if graphSize.width == 0 { graphSize = geometry.size } }
        }
    }

    private func renderNode(_ node: GraphNode) -> some View {
        let isSelected = selectedNodeID == node.id
        // 简单高亮邻居判断
        let isNeighbor = selectedNodeID != nil && filteredEdges.contains { $0.source == selectedNodeID && $0.target == node.id || $0.target == selectedNodeID && $0.source == node.id }
        let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
        
        return GraphNodeView(
            node: node,
            isSelected: isSelected,
            isAnimating: isAnimating,
            linkCount: node.linkCount,
            clusters: provider.clusters,
            useClustering: useClustering,
            onSelect: { onNodeTap(node) },
            heroNamespace: heroNamespace,
            viewportRect: nil,
            scale: scale
        )
        .position(node.position)
        .opacity(isDimmed ? 0.2 : 1.0)
    }
    
    private func drawEdges(in context: GraphicsContext, size: CGSize) {
        let nodeLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let isAnySelected = selectedNodeID != nil
        
        for edge in filteredEdges {
            guard let s = nodeLookup[edge.source], let t = nodeLookup[edge.target] else { continue }
            
            let isHighlighted = selectedNodeID == edge.source || selectedNodeID == edge.target
            let opacity = isHighlighted ? 0.8 : (isAnySelected ? 0.05 : 0.2)
            let lineWidth: CGFloat = isHighlighted ? 2.5 : 1.0
            
            var path = Path()
            path.move(to: s.position)
            path.addLine(to: t.position)
            
            if isHighlighted {
                let gradient = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [s.type.themedColor, t.type.themedColor]),
                    startPoint: s.position, endPoint: t.position
                )
                context.stroke(path, with: gradient, lineWidth: lineWidth)
            } else {
                context.stroke(path, with: .color(.wikiBorder.opacity(opacity)), lineWidth: lineWidth)
            }
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture().onChanged { v in scale = lastScale * v }.onEnded { _ in lastScale = scale }
    }
    private var dragGesture: some Gesture {
        DragGesture().onChanged { v in offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height) }.onEnded { _ in lastOffset = offset }
    }
}

// MARK: - 子视图组件
private struct GraphEmptyStateView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: AppTab
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.wikiAccent.gradient)
            
            VStack(spacing: 8) {
                Text(L10n.Graph.tr("emptyTitle")).font(.title2.bold())
                Text(L10n.Graph.tr("emptyDesc"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { selectedTab = .wiki; store.showCreateSheet = true }) {
                Text(L10n.Graph.tr("startBuilding"))
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.wikiAccent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GraphFilterPillsView: View {
    @Binding var filterType: PageType?
    @ObservedObject var tooltipManager: TooltipManager
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: Localized.tr("search.all"), isSelected: filterType == nil) { filterType = nil }
                ForEach(PageType.allCases) { type in
                    FilterPill(title: type.displayName, icon: type.icon, color: type.themedColor, isSelected: filterType == type) { filterType = type }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
