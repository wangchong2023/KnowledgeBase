// DemoDataGenerator.swift
//
// 作者: Wang Chong
// 功能说明: 演示数据生成器
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import GRDB

/// 演示数据生成器
///
/// 职责：用于快速填充知识库，展示图谱、检索及 AI 分析能力。
/// 该类仅用于 Demo 或开发测试阶段，不应包含任何核心业务逻辑。
struct DemoDataGenerator {
    
    
    /// 执行演示数据生成
    /// - Parameter store: 目标存储对象
    /// - Returns: 生成的页面数量
    @MainActor
    static func generate(in store: SQLiteStore) -> Int {
        print("🧪 [Demo] Starting demo data generation...")
        
        // 1. 确保是一个纯净的演示环境
        store.removeAllPages()
        MedalService.shared.reset()
        
        print("🧪 [Demo] Store cleared.")
        var count = 0
        
        // 2. 使用 performBatchWrite 确保所有演示数据在同一个事务中插入
        store.performBatchWrite { db in
            let pagesToCreate: [(String, PageType, String, [String])] = [
                (Localized.tr("demo.aiAgent.title"), .concept, Localized.tr("demo.aiAgent.content"), ["AI", "Agent", Localized.tr("sidebar.system")]),
                (Localized.tr("demo.planning.title"), .concept, Localized.tr("demo.planning.content"), ["AI", "Planning", Localized.tr("sidebar.tools")]),
                (Localized.tr("demo.memory.title"), .concept, Localized.tr("demo.memory.content"), ["AI", "Memory", "RAG"]),
                (Localized.tr("demo.toolUse.title"), .concept, Localized.tr("demo.toolUse.content"), ["AI", "ToolUse", "API"]),
                (Localized.tr("demo.llm.title"), .concept, Localized.tr("demo.llm.content"), ["AI", "LLM", Localized.tr("sidebar.capabilities")])
            ]
            
            for (title, type, content, tags) in pagesToCreate {
                // 直接使用 WikiPage 的存储能力，避免对 Repository 实例的复杂依赖检查
                let page = WikiPage(title: title, type: type, content: content, tags: tags)
                try page.save(db)
                count += 1
            }
        }
        
        print("🧪 [Demo] Generation finished. Total: \(count)")
        return count
    }

    /// 执行图谱压力测试数据生成 (1000条节点)
    /// - Parameter store: 目标存储对象
    /// - Returns: 生成的页面数量
    @MainActor
    static func generateStressTest(in store: SQLiteStore) -> Int {
        print("🧪 [StressTest] Starting stress test data generation (1000 nodes)...")
        
        // 清理旧数据以获得准确的性能评估
        store.removeAllPages()
        MedalService.shared.reset()
        
        var count = 0
        let targetCount = 1000
        
        store.performBatchWrite { db in
            // 预生成标题列表，用于建立随机链接
            let titles = (1...targetCount).map { "StressNode_\($0)" }
            let types: [PageType] = [.concept, .entity, .source, .comparison, .map]
            
            for i in 0..<targetCount {
                let title = titles[i]
                let type = types[i % types.count]
                
                // 随机选择 1-3 个其他节点建立链接
                var content = "This is a stress test node #\(i+1).\n\n"
                let linkCount = Int.random(in: 1...3)
                var linkedIndices = Set<Int>()
                while linkedIndices.count < linkCount {
                    let randIdx = Int.random(in: 0..<targetCount)
                    if randIdx != i {
                        linkedIndices.insert(randIdx)
                    }
                }
                
                for idx in linkedIndices {
                    content += "Linking to: [[\(titles[idx])]]\n"
                }
                
                let page = WikiPage(
                    title: title,
                    type: type,
                    content: content,
                    tags: ["StressTest", "Performance"]
                )
                
                try page.save(db)
                count += 1
                
                if count % 100 == 0 {
                    print("🧪 [StressTest] Injected \(count) nodes...")
                }
            }
        }
        
        print("🧪 [StressTest] Finished. Total: \(count)")
        return count
    }
}
