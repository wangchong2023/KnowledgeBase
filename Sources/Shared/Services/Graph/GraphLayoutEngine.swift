import Foundation

// MARK: - Graph Layout Engine
/// 力导向布局引擎，将 WikiPage 集合计算为带坐标的 GraphNode/GraphEdge。
struct GraphLayoutEngine {

    /// 布局配置参数
    struct Config {
        var repulsion: CGFloat = 5000
        var attraction: CGFloat = 0.01
        var damping: CGFloat = 0.85
        var centerGravity: CGFloat = 0.005
        var iterations: Int = 100
        var padding: CGFloat = 40

        static let `default` = Config()
    }

    /// 对页面集合执行力导向布局，返回节点和边。
    static func layout(
        pages: [WikiPage],
        linkResolver: (String) -> WikiPage?,
        canvasSize: CGSize,
        config: Config = .default
    ) -> (nodes: [GraphNode], edges: [GraphEdge]) {
        guard !pages.isEmpty else { return ([], []) }

        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let radius = min(centerX, centerY) * 0.65

        // ── 初始圆形布局 ──
        var nodes: [GraphNode] = pages.enumerated().map { index, page in
            let angle = Double(index) / Double(pages.count) * 2 * .pi - .pi / 2
            return GraphNode(
                id: page.id,
                title: page.title,
                type: page.type,
                position: CGPoint(
                    x: centerX + radius * cos(angle),
                    y: centerY + radius * sin(angle)
                )
            )
        }

        // ── 创建边 (确保无向去重) ──
        var edges: [GraphEdge] = []
        for page in pages {
            for link in page.outgoingLinks {
                if let targetPage = linkResolver(link) {
                    // 检查是否已存在该边（无向去重）
                    let alreadyExists = edges.contains { e in
                        (e.source == page.id && e.target == targetPage.id) ||
                        (e.source == targetPage.id && e.target == page.id)
                    }
                    if !alreadyExists && page.id != targetPage.id {
                        edges.append(GraphEdge(source: page.id, target: targetPage.id))
                    }
                }
            }
            for relatedID in page.relatedPageIDs {
                if pages.contains(where: { $0.id == relatedID }) {
                    let alreadyExists = edges.contains { e in
                        (e.source == page.id && e.target == relatedID) ||
                        (e.source == relatedID && e.target == page.id)
                    }
                    if !alreadyExists && page.id != relatedID {
                        edges.append(GraphEdge(source: page.id, target: relatedID))
                    }
                }
            }
        }

        // ── 力导向迭代（模拟退火） ──
        for iteration in 0..<config.iterations {
            let progress = CGFloat(iteration) / CGFloat(config.iterations)
            let temperature = 1.0 - progress * 0.8
            applyForces(
                nodes: &nodes,
                edges: edges,
                canvasWidth: canvasSize.width,
                canvasHeight: canvasSize.height,
                config: config,
                temperature: temperature
            )
        }

        return (nodes, edges)
    }

    /// 单次力迭代。
    static func applyForces(
        nodes: inout [GraphNode],
        edges: [GraphEdge],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        config: Config,
        temperature: CGFloat = 1.0
    ) {
        let effectiveDamping = config.damping * temperature
        let effectiveGravity = config.centerGravity + (1.0 - temperature) * 0.01

        var forces = nodes.map { _ in CGPoint(x: 0, y: 0) }
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2

        // 节点间排斥力
        for i in nodes.indices {
            for j in nodes.indices where i != j {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let force = config.repulsion / (dist * dist)
                forces[i].x += dx / dist * force
                forces[i].y += dy / dist * force
            }
        }

        // 边的吸引力
        for edge in edges {
            guard let i = nodes.firstIndex(where: { $0.id == edge.source }),
                  let j = nodes.firstIndex(where: { $0.id == edge.target }) else { continue }
            let dx = nodes[j].position.x - nodes[i].position.x
            let dy = nodes[j].position.y - nodes[i].position.y
            forces[i].x += dx * config.attraction
            forces[i].y += dy * config.attraction
            forces[j].x -= dx * config.attraction
            forces[j].y -= dy * config.attraction
        }

        // 向心引力
        for i in nodes.indices {
            forces[i].x += (centerX - nodes[i].position.x) * effectiveGravity
            forces[i].y += (centerY - nodes[i].position.y) * effectiveGravity
        }
        
        // ── 社区引力 (Community Gravity) ──
        // 属于同一社区的节点会向该社区的几何中心靠拢，形成"云团"效果
        var communityCenters: [Int: CGPoint] = [:]
        var communityCounts: [Int: Int] = [:]
        
        for node in nodes {
            if let commID = node.communityID {
                communityCenters[commID, default: .zero].x += node.position.x
                communityCenters[commID, default: .zero].y += node.position.y
                communityCounts[commID, default: 0] += 1
            }
        }
        
        for (id, count) in communityCounts where count > 0 {
            communityCenters[id]?.x /= CGFloat(count)
            communityCenters[id]?.y /= CGFloat(count)
        }
        
        for i in nodes.indices {
            if let commID = nodes[i].communityID, let center = communityCenters[commID] {
                let dx = center.x - nodes[i].position.x
                let dy = center.y - nodes[i].position.y
                let clusterAttraction: CGFloat = 0.05 // 主题簇聚合强度
                forces[i].x += dx * clusterAttraction
                forces[i].y += dy * clusterAttraction
            }
        }

        // 应用力 + 边界约束
        for i in nodes.indices {
            nodes[i].position.x += forces[i].x * effectiveDamping
            nodes[i].position.y += forces[i].y * effectiveDamping

            nodes[i].position.x = max(config.padding, min(canvasWidth - config.padding, nodes[i].position.x))
            nodes[i].position.y = max(config.padding, min(canvasHeight - config.padding - 20, nodes[i].position.y))
        }
    }
}

extension GraphLayoutEngine {

    // MARK: - Community Detection

    /// 使用 Louvain 算法检测社区，返回带社区信息的节点
    static func detectCommunities(nodes: [GraphNode], edges: [GraphEdge]) -> [GraphNode] {
        guard !nodes.isEmpty else { return [] }

        var workingNodes = nodes
        let nodeIDs = Set(nodes.map { $0.id })
        guard nodeIDs.count >= 1 else { return workingNodes }

        // 构建邻接表
        var adjacency: [UUID: Set<UUID>] = [:]
        var nodeDegree: [UUID: Int] = [:]
        for node in workingNodes {
            adjacency[node.id] = []
            nodeDegree[node.id] = 0
        }

        // 构建无向边（避免重复）
        var undirectedEdges: Set<EdgePair> = []
        for edge in edges {
            if nodeIDs.contains(edge.source) && nodeIDs.contains(edge.target) {
                undirectedEdges.insert(EdgePair(min(edge.source, edge.target), max(edge.source, edge.target)))
            }
        }

        // 填充邻接表和度数
        for edge in undirectedEdges {
            adjacency[edge.source]?.insert(edge.target)
            adjacency[edge.target]?.insert(edge.source)
            nodeDegree[edge.source, default: 0] += 1
            nodeDegree[edge.target, default: 0] += 1
        }

        let m = Double(undirectedEdges.count) // 总边数
        guard m > 0 else {
            // 无边的情况，所有节点独立社区
            for i in workingNodes.indices {
                workingNodes[i].communityID = i
                workingNodes[i].communityCohesion = 1.0
            }
            return workingNodes
        }

        // 初始化每个节点为独立社区
        var community: [UUID: Int] = [:]
        var communityNodes: [Int: Set<UUID>] = [:]
        for (index, node) in workingNodes.enumerated() {
            community[node.id] = index
            communityNodes[index] = [node.id]
        }

        var currentModularity = calculateModularity(community: community, adjacency: adjacency, nodeDegree: nodeDegree, m: m)

        // 迭代优化
        var improved = true
        var iteration = 0
        let maxIterations = 10

        while improved && iteration < maxIterations {
            improved = false
            iteration += 1

            for nodeID in nodeIDs {
                let currentComm = community[nodeID]!

                // 获取邻居社区
                var neighborCommunities: [Int: [UUID]] = [:]
                if let neighbors = adjacency[nodeID] {
                    for neighbor in neighbors {
                        let neighborComm = community[neighbor]!
                        if neighborComm != currentComm {
                            neighborCommunities[neighborComm, default: []].append(neighbor)
                        }
                    }
                }

                // 尝试移动到每个邻居社区
                var bestComm = currentComm
                var bestGain = 0.0

                for (targetComm, _) in neighborCommunities {
                    let gain = calculateModularityGain(
                        nodeID: nodeID,
                        targetComm: targetComm,
                        currentComm: currentComm,
                        adjacency: adjacency,
                        nodeDegree: nodeDegree,
                        community: community,
                        communityNodes: communityNodes,
                        m: m
                    )
                    if gain > bestGain {
                        bestGain = gain
                        bestComm = targetComm
                    }
                }

                if bestGain > 0 && bestComm != currentComm {
                    // 移动节点到更好的社区
                    communityNodes[currentComm]?.remove(nodeID)
                    communityNodes[bestComm, default: []].insert(nodeID)
                    community[nodeID] = bestComm
                    improved = true
                }
            }

            let newModularity = calculateModularity(community: community, adjacency: adjacency, nodeDegree: nodeDegree, m: m)
            if newModularity <= currentModularity {
                improved = false
            } else {
                currentModularity = newModularity
            }
        }

        // 计算社区内聚力
        var communityInternalEdges: [Int: Int] = [:]
        var communityTotalEdges: [Int: Int] = [:]

        for edge in undirectedEdges {
            let comm0 = community[edge.source]!
            let comm1 = community[edge.target]!
            communityTotalEdges[comm0, default: 0] += 1
            communityTotalEdges[comm1, default: 0] += 1
            if comm0 == comm1 {
                communityInternalEdges[comm0, default: 0] += 1
            }
        }

        // 分配社区 ID 和内聚力
        var nodeIndexMap: [UUID: Int] = [:]
        for (index, node) in workingNodes.enumerated() {
            nodeIndexMap[node.id] = index
        }

        for nodeID in nodeIDs {
            let comm = community[nodeID]!
            let internalEdges = communityInternalEdges[comm] ?? 0
            let totalEdges = communityTotalEdges[comm] ?? 1
            let cohesion = Double(internalEdges) / Double(totalEdges)

            if let idx = nodeIndexMap[nodeID] {
                workingNodes[idx].communityID = comm
                workingNodes[idx].communityCohesion = cohesion
            }
        }

        return workingNodes
    }

    /// 计算模块度
    private static func calculateModularity(
        community: [UUID: Int],
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        m: Double
    ) -> Double {
        guard m > 0 else { return 0 }

        var Q = 0.0
        for (nodeID, neighbors) in adjacency {
            let ki = Double(nodeDegree[nodeID] ?? 0)
            for neighborID in neighbors {
                if nodeID < neighborID { // 每条边只计算一次
                    let kj = Double(nodeDegree[neighborID] ?? 0)
                    let sameCommunity = community[nodeID] == community[neighborID] ? 1.0 : 0.0
                    Q += (1.0 - (ki * kj) / (2 * m)) * sameCommunity
                }
            }
        }
        return Q / (2 * m)
    }

    /// 计算将节点移动到目标社区的模块度增益
    private static func calculateModularityGain(
        nodeID: UUID,
        targetComm: Int,
        currentComm: Int,
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        community: [UUID: Int],
        communityNodes: [Int: Set<UUID>],
        m: Double
    ) -> Double {
        guard m > 0 else { return 0 }

        let ki = Double(nodeDegree[nodeID] ?? 0)

        // 计算目标社区的内部边数和度数
        var targetInternalEdges = 0
        var targetTotalDegree = 0

        if let neighbors = adjacency[nodeID] {
            for neighborID in neighbors {
                if community[neighborID] == targetComm {
                    targetInternalEdges += 1
                }
                targetTotalDegree += nodeDegree[neighborID] ?? 0
            }
        }

        let kcInTarget = Double(targetInternalEdges)
        let sumKjInTarget = Double(targetTotalDegree)

        // 模块度增益公式
        let gain = (kcInTarget - (ki * sumKjInTarget) / (2 * m)) - (ki / (2 * m)) * (sumKjInTarget - ki)
        return gain
    }

    /// 获取低内聚力社区的节点 ID
    static func lowCohesionCommunities(nodes: [GraphNode], threshold: Double = 0.15) -> [UUID] {
        return nodes.filter { node in
            if let cohesion = node.communityCohesion {
                return cohesion < threshold
            }
            return false
        }.map { $0.id }
    }

    /// 获取孤立页面（无任何连接的节点）
    static func orphanNodes(nodes: [GraphNode], edges: [GraphEdge]) -> [UUID] {
        var connectedNodes: Set<UUID> = []
        for edge in edges {
            connectedNodes.insert(edge.source)
            connectedNodes.insert(edge.target)
        }
        return nodes.filter { !connectedNodes.contains($0.id) }.map { $0.id }
    }
    
    /// 综合检测所有类型的洞察：意外关联、孤立页面、稀疏社区、桥接节点
    /// - Returns: (surprisingConnections, orphans, sparseCommunity, bridges)
    static func detectInsights(
        nodes: [GraphNode],
        edges: [GraphEdge],
        pages: [WikiPage]
    ) -> (surprising: [UUID], orphans: [UUID], sparse: [UUID], bridges: [UUID]) {
        
        // 1. 孤立页面
        let orphans = orphanNodes(nodes: nodes, edges: edges)
        
        // 2. 低内聚力社区（稀疏社区）
        let sparse = lowCohesionCommunities(nodes: nodes, threshold: 0.15)
        
        // 3. 桥接节点（连接多个社区的节点）
        var nodeCommunities: [UUID: Set<Int>] = [:]
        var nodeNeighbors: [UUID: Set<UUID>] = [:]
        
        for node in nodes {
            nodeCommunities[node.id] = node.communityID.map { Set([$0]) } ?? Set()
            nodeNeighbors[node.id] = Set()
        }
        
        for edge in edges {
            nodeNeighbors[edge.source, default: Set()].insert(edge.target)
            nodeNeighbors[edge.target, default: Set()].insert(edge.source)
        }
        
        // 构建社区成员映射
        var communityMembers: [Int: Set<UUID>] = [:]
        for node in nodes {
            if let comm = node.communityID {
                communityMembers[comm, default: Set()].insert(node.id)
            }
        }
        
        // 计算跨社区边
        var crossCommunityEdges: [UUID: Int] = [:]
        for edge in edges {
            let srcComm = nodes.first { $0.id == edge.source }?.communityID
            let tgtComm = nodes.first { $0.id == edge.target }?.communityID
            
            if let sc = srcComm, let tc = tgtComm, sc != tc {
                crossCommunityEdges[edge.source, default: 0] += 1
                crossCommunityEdges[edge.target, default: 0] += 1
            }
        }
        
        // 桥接节点：连接 >= 3 个不同社区
        var bridges: [UUID] = []
        for edge in edges {
            let srcComm = nodes.first { $0.id == edge.source }?.communityID
            let tgtComm = nodes.first { $0.id == edge.target }?.communityID
            
            if let sc = srcComm, let tc = tgtComm, sc != tc {
                // 检查两个节点各自连接了多少个不同社区
                let srcConnectedCommunities = countDistinctCommunities(node: edge.source, neighbor: edge.target, nodes: nodes, edges: edges)
                let tgtConnectedCommunities = countDistinctCommunities(node: edge.target, neighbor: edge.source, nodes: nodes, edges: edges)
                
                if srcConnectedCommunities >= 3 { bridges.append(edge.source) }
                if tgtConnectedCommunities >= 3 { bridges.append(edge.target) }
            }
        }
        
        // 4. 意外关联：跨社区边连接的节点
        var surprising: Set<UUID> = []
        for edge in edges {
            let srcComm = nodes.first { $0.id == edge.source }?.communityID
            let tgtComm = nodes.first { $0.id == edge.target }?.communityID
            
            if let sc = srcComm, let tc = tgtComm, sc != tc {
                // 类型不同的跨社区连接更"意外"
                let srcType = nodes.first { $0.id == edge.source }?.type
                let tgtType = nodes.first { $0.id == edge.target }?.type
                if srcType != tgtType {
                    surprising.insert(edge.source)
                    surprising.insert(edge.target)
                }
            }
        }
        
        return (Array(surprising), orphans, sparse, Array(Set(bridges)))
    }
    
    /// 计算节点连接的独立社区数量
    private static func countDistinctCommunities(node: UUID, neighbor: UUID, nodes: [GraphNode], edges: [GraphEdge]) -> Int {
        var neighborIDs: Set<UUID> = []
        for edge in edges {
            if edge.source == node { neighborIDs.insert(edge.target) }
            if edge.target == node { neighborIDs.insert(edge.source) }
        }
        
        var communities: Set<Int> = []
        for n in neighborIDs {
            if let comm = nodes.first(where: { $0.id == n })?.communityID {
                communities.insert(comm)
            }
        }
        return communities.count
    }
}

// MARK: - Helper Types

/// 无向边表示，用于去重
private struct EdgePair: Hashable {
    let source: UUID
    let target: UUID

    init(_ source: UUID, _ target: UUID) {
        self.source = source
        self.target = target
    }
}
