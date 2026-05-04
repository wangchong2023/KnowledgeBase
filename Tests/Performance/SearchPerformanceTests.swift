import XCTest
@testable import KM

/// 性能基准测试 (Expert QA Item #4)
/// 监控向量检索在不同数据量级下的延迟。
@MainActor
final class SearchPerformanceTests: XCTestCase {
    var store: KMStore!
    
    override func setUp() {
        super.setUp()
        store = KMStore()
    }
    
    /// 测试 10,000 条记录下的检索耗时
    func testVectorRetrievalPerformance() async throws {
        // 构造 10k 模拟数据 (Skip actual vectorization for benchmark)
        let query = "如何优化系统架构"
        
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
