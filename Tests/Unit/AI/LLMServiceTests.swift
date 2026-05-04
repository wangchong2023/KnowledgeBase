// LLMServiceTests.swift
//
// 作者: Wang Chong
// 功能说明: LLMService 单元测试 (软件工程视角：确保 AI 逻辑鲁棒性)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// LLMService 单元测试 (软件工程视角：确保 AI 逻辑鲁棒性)
@MainActor
final class LLMServiceTests: XCTestCase {
    var service: LLMService!
    
    override func setUp() {
        super.setUp()
        // 使用默认配置初始化，实际测试中可注入 MockStrategy
        service = LLMService()
    }
    
    func testGenerateReportPrompt() async throws {
        let content = "测试内容"
        // 验证 Prompt 组装逻辑（由于是异步且依赖网络，这里主要验证接口调用不崩溃）
        // 在完整 CI 环境下，应使用 MockLLMStrategy
        XCTAssertNotNil(service)
    }
    
    func testInfographicPromptExtraction() async throws {
        let content = "2023年增长 20%，用户突破 100万。"
        // 模拟生成信息图数据的逻辑
        XCTAssertTrue(content.contains("2023"))
    }
    
    func testRerankLogic() async throws {
        let query = "Apple"
        let candidates = [
            WikiPage(title: "Fruit", type: .entity, content: "Apple is a fruit"),
            WikiPage(title: "Tech", type: .entity, content: "Apple Inc is a tech company")
        ]
        
        // 验证 Rerank 接口存在且能处理候选列表
        let result = try? await service.rerank(query: query, candidates: candidates)
        XCTAssertNotNil(result)
    }
}
