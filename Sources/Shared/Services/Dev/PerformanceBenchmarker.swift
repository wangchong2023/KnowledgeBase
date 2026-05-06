// PerformanceBenchmarker.swift
//
// 作者: Wang Chong
// 功能说明: 性能压测工具 (仅限 Debug/Internal 使用)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 性能压测工具 (仅限 Debug/Internal 使用)
/// 专门用于验证 50,000+ 文档规模下的系统承载力
@MainActor
final class PerformanceBenchmarker {
    static let shared = PerformanceBenchmarker()
    
    /// 模拟海量文档导入并测量索引耗时
    func runStressTest(count: Int = 50000, store: SQLiteStore) async {
        print("🚀 [Benchmark] 开始极限压测：生成 \(count) 篇文档...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 批量创建模拟数据
        for i in 1...count {
            if i % 5000 == 0 {
                let currentTotal = store.totalPages
                print("⏳ [Benchmark] 已注入 \(i) 篇... 当前 DB 总数: \(currentTotal)")
            }
            
            _ = store.createPage(
                title: "Stress Test Page #\(i)",
                type: .raw,
                content: "这是第 \(i) 篇压测文档。它包含了模拟的文本内容，用于测试 SQLite FTS5 的索引性能以及向量检索的内存占用。\(UUID().uuidString)",
                tags: ["benchmark", "stress-test"]
            )
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ [Benchmark] 压测数据注入完成！")
        print("⏱️ 总耗时: \(String(format: "%.2f", duration))s")
        print("📈 平均速度: \(String(format: "%.2f", Double(count)/duration)) docs/s")
        
        // 触发一次全量搜索测试
        measureSearchPerformance(store: store)
    }
    
    private func measureSearchPerformance(store: SQLiteStore) {
        let query = "Stress Test"
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let results = store.searchPages(query: query)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("🔍 [Benchmark] 搜索性能：\"\(query)\"")
        print("⏱️ 响应延迟: \(String(format: "%.2f", duration * 1000))ms")
        print("📄 召回数量: \(results.count)")
        
        if duration > 0.8 {
            print("⚠️ [Warning] 检索延迟超过 800ms 红线！需要优化索引策略。")
        }
    }
}
