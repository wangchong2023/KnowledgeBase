// GraphLayoutEngine.swift
//
// 作者: Wang Chong
// 功能说明: 力导向布局引擎，将 WikiPage 集合计算为带坐标的 GraphNode/GraphEdge。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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

        // ── 动态画布计算 ──
        // 节点越多，虚拟画布越大，防止过度拥挤
        let nodeCount = pages.count
        let baseExpansion = 1.0 + CGFloat(max(0, nodeCount - 20)) * 0.05
        let virtualWidth = canvasSize.width * baseExpansion
        let virtualHeight = canvasSize.height * baseExpansion

        let centerX = virtualWidth / 2
        let centerY = virtualHeight / 2
        let radius = min(virtualWidth, virtualHeight) * 0.4 // 初始半径更保守

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
        let effectiveDamping = config.damping * temperature
        let effectiveGravity = config.centerGravity + (1.0 - temperature) * 0.01

        var forces = nodes.map { _ in CGPoint(x: 0, y: 0) }
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2

        // ── 空间索引优化：网格剖分排斥力计算 (O(N^2) -> O(N)) ──
        let gridSize: CGFloat = 150 // 网格大小
        var grid: [String: [Int]] = [:]
        
        // 1. 将节点分配到网格
        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)
            grid["\(gx),\(gy)", default: []].append(i)
        }
        
        // 2. 仅计算相邻网格内的排斥力
        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)
            
            for ox in -1...1 {
                for oy in -1...1 {
                    let key = "\(gx + ox),\(gy + oy)"
                    guard let neighbors = grid[key] else { continue }
                    
                    for j in neighbors where i != j {
                        let dx = nodes[i].position.x - nodes[j].position.x
                        let dy = nodes[i].position.y - nodes[j].position.y
                        let distSq = dx * dx + dy * dy
                        let dist = sqrt(distSq)
                        
                        if dist < gridSize && dist > 1 {
                            let force = config.repulsion / distSq
                            forces[i].x += dx / dist * force
                            forces[i].y += dy / dist * force
                        }
                    }
                }
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
