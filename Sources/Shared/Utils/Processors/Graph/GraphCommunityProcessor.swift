// GraphCommunityProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了基于图拓扑结构的社区发现处理器（GraphCommunityProcessor），旨在挖掘知识网络中的深层聚合特征。
// 该处理器通过以下核心技术识别知识簇：
// 1. 模块化算法：采用 Louvain 或同类启发式算法，通过最大化模块化增量（Modularity Gain）来识别节点紧密关联的社区。
// 2. 关系权重分析：综合考虑节点间的链接密度与交互频率，动态计算社区边界，实现自动化的知识分类。
// 3. 结果层次化：支持多级社区划分，能够从宏观视角展示知识全景，亦能深入微观视角观察细分领域，为知识洞察提供数据支撑。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Graph 并规范化社区发现算法描述
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

// MARK: - 社区发现
extension GraphLayoutProcessor {

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
}

// MARK: - 辅助类型

/// 无向边表示，用于去重
struct EdgePair: Hashable {
    let source: UUID
    let target: UUID

    init(_ source: UUID, _ target: UUID) {
        self.source = source
        self.target = target
    }
}
