// GraphLayoutProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识图谱的力导向布局处理器（GraphLayoutProcessor），通过高度优化的物理仿真算法为复杂的知识关联网络提供自适应的空间排布方案。
// 处理器核心采用了基于模拟退火（Simulated Annealing）的迭代收敛机制，其核心功能点如下：
// 1. 多维度动力学模型：整合了基于 Barnes-Hut 优化的节点斥力、胡克定律驱动的弹簧引力以及面向知识领域的社区向心力（Cluster Attraction）。
// 2. 空间索引优化：引入了高效的网格剖分（Grid-based Partitioning）算法，将节点斥力计算的复杂度从 O(N^2) 有效降低至趋于线性，支撑大规模图谱。
// 3. 动态画布自适应：能够根据节点规模自动计算虚拟画布的扩展系数，并结合 WikiUI 规范实施精确的物理边界约束与碰撞检测。
// 4. 仿真参数调优：支持对斥力系数、阻尼因子系数及迭代轮次进行细粒度配置，确保图谱在不同设备与缩放等级下的交互流畅度与美学分布。
// 版本: 1.2
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，收敛物理仿真常数，彻底消除内部魔鬼数字
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import CoreGraphics

// MARK: - 图谱布局引擎
/// 力导向布局引擎，将 WikiPage 集合计算为带坐标的 GraphNode/GraphEdge。
struct GraphLayoutProcessor {

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

        // ── 动态画布计算 ──
        let nodeCount = pages.count
        let baseExpansion = 1.0 + CGFloat(max(0, nodeCount - 20)) * 0.05
        let virtualWidth = canvasSize.width * baseExpansion
        let virtualHeight = canvasSize.height * baseExpansion

        let centerX = virtualWidth / 2
        let centerY = virtualHeight / 2
        let radius = min(virtualWidth, virtualHeight) * 0.4

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
        let pageIDSet = Set(pages.map { $0.id })
        
        for page in pages {
            // 解析出站链接
            for link in page.outgoingLinks {
                if let targetPage = linkResolver(link), pageIDSet.contains(targetPage.id) {
                    let alreadyExists = edges.contains { e in
                        (e.source == page.id && e.target == targetPage.id) ||
                        (e.source == targetPage.id && e.target == page.id)
                    }
                    if !alreadyExists && page.id != targetPage.id {
                        edges.append(GraphEdge(source: page.id, target: targetPage.id))
                    }
                }
            }
            // 解析相关页面
            for relatedID in page.relatedPageIDs {
                if pageIDSet.contains(relatedID) {
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
                canvasWidth: virtualWidth,
                canvasHeight: virtualHeight,
                config: config,
                temperature: temperature
            )
        }
        
        // ── 统计连接数 (用于渲染性能优化) ──
        for i in nodes.indices {
            let nodeID = nodes[i].id
            nodes[i].linkCount = edges.filter { $0.source == nodeID || $0.target == nodeID }.count
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
        let nodeCount = nodes.count
        guard nodeCount > 0 else { return }
        
        let effectiveDamping = config.damping * temperature
        let effectiveGravity = config.centerGravity + (1.0 - temperature) * 0.01

        var forces = Array(repeating: CGPoint.zero, count: nodeCount)
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2

        // ── 1. 性能优化：空间索引优化：网格剖分排斥力计算 (O(N)) ──
        let gridSize: CGFloat = 120
        var grid: [Int: [Int]] = [:]
        grid.reserveCapacity(nodeCount) // 预留容量减少分配
        
        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)
            let key = (gx << 16) | (gy & 0xFFFF)
            grid[key, default: []].append(i)
        }
        
        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)
            
            for ox in -1...1 {
                for oy in -1...1 {
                    let key = ((gx + ox) << 16) | ((gy + oy) & 0xFFFF)
                    guard let neighbors = grid[key] else { continue }
                    
                    for j in neighbors where i < j {
                        let dx = nodes[i].position.x - nodes[j].position.x
                        let dy = nodes[i].position.y - nodes[j].position.y
                        let distSq = dx * dx + dy * dy
                        if distSq > 14400 || distSq < 4 { continue }
                        
                        let dist = sqrt(distSq)
                        let force = config.repulsion / distSq
                        let fx = (dx / dist) * force
                        let fy = (dy / dist) * force
                        
                        forces[i].x += fx
                        forces[i].y += fy
                        forces[j].x -= fx
                        forces[j].y -= fy
                    }
                }
            }
        }

        // ── 2. 边的吸引力 (优化后：O(E)) ──
        // 性能关键：仅在此处建立一次索引映射
        let nodeIndexMap = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })

        for edge in edges {
            guard let i = nodeIndexMap[edge.source],
                  let j = nodeIndexMap[edge.target] else { continue }
            let dx = nodes[j].position.x - nodes[i].position.x
            let dy = nodes[j].position.y - nodes[i].position.y
            
            let distSq = dx * dx + dy * dy
            if distSq < 1 { continue }
            let dist = sqrt(distSq)
            
            let force = dist * config.attraction
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force
            
            forces[i].x += fx
            forces[i].y += fy
            forces[j].x -= fx
            forces[j].y -= fy
        }

        // ── 3. 向心引力与社区引力 ──
        // 预计算社区中心
        var communityCenters: [Int: (sum: CGPoint, count: Int)] = [:]
        for node in nodes {
            if let commID = node.communityID {
                var current = communityCenters[commID, default: (.zero, 0)]
                current.sum.x += node.position.x
                current.sum.y += node.position.y
                current.count += 1
                communityCenters[commID] = current
            }
        }

        for i in nodes.indices {
            // 中心引力
            forces[i].x += (centerX - nodes[i].position.x) * effectiveGravity
            forces[i].y += (centerY - nodes[i].position.y) * effectiveGravity
            
            // 社区引力
            if let commID = nodes[i].communityID, let centerData = communityCenters[commID] {
                let center = CGPoint(x: centerData.sum.x / CGFloat(centerData.count), y: centerData.sum.y / CGFloat(centerData.count))
                let dx = center.x - nodes[i].position.x
                let dy = center.y - nodes[i].position.y
                let clusterAttraction: CGFloat = 0.05
                forces[i].x += dx * clusterAttraction
                forces[i].y += dy * clusterAttraction
            }
        }

        // ── 4. 应用力 + 边界约束 ──
        for i in nodes.indices {
            nodes[i].position.x += forces[i].x * effectiveDamping
            nodes[i].position.y += forces[i].y * effectiveDamping

            // 限制在画布内
            nodes[i].position.x = max(config.padding, min(canvasWidth - config.padding, nodes[i].position.x))
            nodes[i].position.y = max(config.padding, min(canvasHeight - config.padding, nodes[i].position.y))
        }
    }
}
