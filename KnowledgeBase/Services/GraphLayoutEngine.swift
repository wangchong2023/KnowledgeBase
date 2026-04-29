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

        // ── 创建边 ──
        var edges: [GraphEdge] = []
        for page in pages {
            for link in page.outgoingLinks {
                if let targetPage = linkResolver(link) {
                    if !edges.contains(where: { $0.source == page.id && $0.target == targetPage.id }) {
                        edges.append(GraphEdge(source: page.id, target: targetPage.id))
                    }
                }
            }
            for relatedID in page.relatedPageIDs {
                if pages.contains(where: { $0.id == relatedID }),
                   !edges.contains(where: { $0.source == page.id && $0.target == relatedID }) {
                    edges.append(GraphEdge(source: page.id, target: relatedID))
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

        // 应用力 + 边界约束
        for i in nodes.indices {
            nodes[i].position.x += forces[i].x * effectiveDamping
            nodes[i].position.y += forces[i].y * effectiveDamping

            nodes[i].position.x = max(config.padding, min(canvasWidth - config.padding, nodes[i].position.x))
            nodes[i].position.y = max(config.padding, min(canvasHeight - config.padding - 20, nodes[i].position.y))
        }
    }
}
