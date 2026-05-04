// GraphLayoutEngineTests.swift
//
// 作者: Wang Chong
// 功能说明: 力导向图谱布局引擎测试
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 力导向图谱布局引擎测试
/// 验证 GraphLayoutEngine 的布局计算、边创建及边界条件处理。
final class GraphLayoutEngineTests: XCTestCase {

    // MARK: - 空输入

    func testLayoutEmptyPagesReturnsEmptyNodesAndEdges() {
        let size = CGSize(width: 800, height: 600)
        let result = GraphLayoutEngine.layout(
            pages: [],
            linkResolver: { _ in nil },
            canvasSize: size
        )
        XCTAssertTrue(result.nodes.isEmpty, "空页面集应返回空节点")
        XCTAssertTrue(result.edges.isEmpty, "空页面集应返回空边")
    }

    // MARK: - 单页面

    func testLayoutSinglePageReturnsOneNodeNoEdges() {
        let page = WikiPage(title: "单页", content: "内容")
        let size = CGSize(width: 800, height: 600)
        let result = GraphLayoutEngine.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: size
        )
        XCTAssertEqual(result.nodes.count, 1, "单页面应生成 1 个节点")
        XCTAssertEqual(result.nodes.first?.id, page.id)
        XCTAssertTrue(result.edges.isEmpty, "无链接页面不应生成边")
    }

    // MARK: - 链接与边创建
    
    func testLayoutWithBidirectionalLinks() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[B]]")
        let pageB = WikiPage(title: "B", type: .concept, content: "Links to [[A]]")

        let result = GraphLayoutEngine.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "A" { return pageA }
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(result.nodes.count, 2)
        XCTAssertEqual(result.edges.count, 2, "双向链接应生成两条边")
    }

    func testLayoutWithOneWayLink() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[B]]")
        let pageB = WikiPage(title: "B", type: .concept, content: "No outgoing links")

        let result = GraphLayoutEngine.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(result.nodes.count, 2)
        XCTAssertEqual(result.edges.count, 1, "单向链接应生成一条边")
        XCTAssertEqual(result.edges.first?.source, pageA.id)
        XCTAssertEqual(result.edges.first?.target, pageB.id)
    }

    func testLayoutNoDuplicateEdges() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[B]] and [[B]]")
        let pageB = WikiPage(title: "B", type: .concept, content: "Content")

        let result = GraphLayoutEngine.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: 800, height: 600)
        )

        let linkCount = result.edges.filter { $0.source == pageA.id && $0.target == pageB.id }.count
        XCTAssertEqual(linkCount, 1, "内容中重复的链接不应生成重复的边")
    }
    
    // MARK: - 边界与辅助属性
    
    func testLayoutRelatedPageIDsCreateEdges() {
        var pageA = WikiPage(title: "A", type: .entity, content: "Content")
        var pageB = WikiPage(title: "B", type: .concept, content: "Content")
        pageB.relatedPageIDs = [pageA.id]

        let result = GraphLayoutEngine.layout(
            pages: [pageA, pageB],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(result.edges.count, 1, "relatedPageIDs 应生成边")
        XCTAssertEqual(result.edges.first?.source, pageB.id)
        XCTAssertEqual(result.edges.first?.target, pageA.id)
    }

    func testLayoutWithBrokenLinkDoesNotCreateEdge() {
        let pageA = WikiPage(title: "A", type: .entity, content: "Links to [[NonExistent]]")

        let result = GraphLayoutEngine.layout(
            pages: [pageA],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(result.nodes.count, 1)
        XCTAssertTrue(result.edges.isEmpty, "断开或不存在的链接不应生成边")
    }

    func testLayoutNodePositionsWithinCanvas() {
        let pages = (0..<10).map { WikiPage(title: "P\($0)", content: "") }
        let canvasSize = CGSize(width: 800, height: 600)
        let result = GraphLayoutEngine.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: canvasSize
        )

        for node in result.nodes {
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.x, canvasSize.width)
            XCTAssertLessThanOrEqual(node.position.y, canvasSize.height)
        }
    }

    // MARK: - 多页面布局

    func testLayoutMultiplePagesCreatesNodesForAll() {
        let pages = (0..<20).map { WikiPage(title: "页面\($0)", content: "") }
        let size = CGSize(width: 1024, height: 768)
        let result = GraphLayoutEngine.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: size
        )
        XCTAssertEqual(result.nodes.count, pages.count, "应生成与输入数量相同的节点")
    }

    // MARK: - 节点位置不重叠

    func testLayoutNodePositionsAreDistinct() {
        let pages = (0..<50).map { WikiPage(title: "P\($0)", content: "") }
        let size = CGSize(width: 1024, height: 1024)
        let result = GraphLayoutEngine.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: size,
            config: GraphLayoutEngine.Config(iterations: 200)
        )
        let positions = result.nodes.map { $0.position }
        XCTAssertEqual(Set(positions.map { "\(Int($0.x)),\(Int($0.y))" }).count,
                       positions.count,
                       "力导向布局后所有节点位置应互不相同")
    }

    // MARK: - 边创建

    func testLayoutCreatesEdgesForWikiLinks() {
        let target = WikiPage(title: "目标页面", content: "")
        let source = WikiPage(title: "源页面", content: "链接 [[目标页面]]")
        let pages = [source, target]
        let size = CGSize(width: 800, height: 600)

        let linkMap: [String: WikiPage] = [
            "目标页面": target
        ]
        let result = GraphLayoutEngine.layout(
            pages: pages,
            linkResolver: { linkMap[$0] },
            canvasSize: size
        )
        XCTAssertFalse(result.edges.isEmpty, "存在 [[链接]] 时应生成边")
        XCTAssertTrue(result.edges.contains(where: { $0.source == source.id && $0.target == target.id }),
                      "应包含从源页面到目标页面的边")
    }

    // MARK: - 孤立节点

    func testLayoutIsolatedNodeHasNoEdges() {
        let isolated = WikiPage(title: "孤立节点", content: "")
        let size = CGSize(width: 800, height: 600)
        let result = GraphLayoutEngine.layout(
            pages: [isolated],
            linkResolver: { _ in nil },
            canvasSize: size
        )
        XCTAssertTrue(result.edges.isEmpty, "孤立节点不应产生边")
        XCTAssertEqual(result.nodes.count, 1)
    }
}
