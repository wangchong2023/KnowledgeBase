// SearchPerformanceTests.swift
//
// 作者: Wang Chong
// 功能说明: 性能基准测试 (Expert QA Item #4)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 性能基准测试 (Expert QA Item #4)
/// 监控向量检索在不同数据量级下的延迟。
@MainActor
final class SearchPerformanceTests: XCTestCase {
    var store: KMStore!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        DatabaseManager.shared.reset()

        let testDBURL = URL(string: "file::memory:?cache=shared")!
        let sqliteStore = SQLiteStore(dbURL: testDBURL)
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(LogService(), for: LogServiceProtocol.self)
        ServiceContainer.shared.register(LinkService(), for: LinkService.self)
        ServiceContainer.shared.register(LintService(), for: LintService.self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(BackupService(), for: BackupService.self)

        store = KMStore()
    }

    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    /// 测试 10,000 条记录下的检索耗时
    func testVectorRetrievalPerformance() async throws {
        // 构造 10k 模拟数据 (Skip actual vectorization for benchmark)
        let query = "如何优化系统架构"

        var testPages: [WikiPage] = []
        testPages.reserveCapacity(10_000)

        for i in 0..<10_000 {
            let title: String
            let content: String
            switch i % 20 {
            case 0:
                // 包含完整查询词，标题也含关键词
                title = "system_architecture_\(i)"
                content = "关于如何优化系统架构的深度分析，编号 \(i)，包括性能调优和可扩展性设计。"
            case 1:
                // 含部分查询词
                title = "optimization_notes_\(i)"
                content = "讨论系统优化策略，包括架构层面和代码层面的改进方案。"
            case 2:
                // 标题含架构相关词
                title = "architecture_review_\(i)"
                content = "系统架构评审报告，编号 \(i)，涵盖模块划分和接口设计。"
            case 3:
                // 标题含优化相关词
                title = "performance_tuning_\(i)"
                content = "性能优化实践指南，编号 \(i)，包含缓存策略和索引优化。"
            default:
                // 普通文档，不包含查询词
                title = "document_\(i)"
                content = "这是第 \(i) 号文档，包含一些常规内容，用于填充搜索空间以测试性能。"
            }
            let page = WikiPage(
                id: UUID(),
                title: title,
                content: content
            )
            testPages.append(page)
        }

        // 将模拟数据写入存储
        store.replaceAllPages(testPages)
        // 直接同步 pages 数组，确保测量时数据已就绪
        store.sqliteStore.pages = testPages

        // 记录开始时间
        let start = CFAbsoluteTimeGetCurrent()

        // 执行混合检索
        _ = await store.linkService.search(query: query, in: store.pages)

        let diff = CFAbsoluteTimeGetCurrent() - start
        let ms = diff * 1000

        print("🚀 [Performance] 10k 检索耗时: \(String(format: "%.2f", ms)) ms")

        // 阈值告警：10k 数据检索不应超过 200ms
        XCTAssertLessThan(ms, 200.0, "向量检索性能超出预期阈值")
    }
}
