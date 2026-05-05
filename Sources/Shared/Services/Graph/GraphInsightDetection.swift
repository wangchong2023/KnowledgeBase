// GraphInsightDetection.swift
//
// 作者: Wang Chong
// 功能说明: 获取孤立页面（无任何连接的节点）
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

// MARK: - Insight Detection
extension GraphLayoutProcessor {

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
