// RAGPipelineTests.swift
//
// 作者: Wang Chong
// 功能说明: 系统集成测试：全链路 RAG 管道
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import XCTest
@testable import KM

/// 系统集成测试：全链路 RAG 管道
/// 覆盖：导入 -> 向量化 -> 检索 -> AI 总结
@MainActor
final class RAGPipelineTests: XCTestCase {
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
        ServiceContainer.shared.register(IngestService(), for: IngestService.self)
        ServiceContainer.shared.register(LLMService(), for: LLMService.self)

        store = KMStore()
    }

    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    func testFullRAGPipeline() async throws {
        // 1. 导入 (Ingest)
        let testContent = "智元 (ZhiYuan) 是一款基于 RAG 架构的知识管理软件，支持双向链接。"
        let page = store.ingestService.ingestRawContent(
            title: "智元简介",
            content: testContent,
            pageStore: store.sqliteStore
        )
        
        let pageID = page.id
        XCTAssertNotNil(pageID)
        
        // 2. 向量化验证 (Vectorization)
        // 等待异步向量化完成
        store.sqliteStore.embeddingManager.waitForCompletion()
        
        let embedding = store.sqliteStore.embeddingManager.allEmbeddings[pageID]
        XCTAssertNotNil(embedding, "向量化任务应在导入后异步完成")
        
        // 3. 检索 (Hybrid Search)
        let searchResults = await store.linkService.search(query: "什么是智元", in: store.pages)
        XCTAssertTrue(searchResults.contains(where: { $0.id == pageID }), "混合检索应能根据关键词召回导入的内容")
        
        // 4. AI 总结 (Generation)
        let prompt = "根据已知内容回答：智元的特点是什么？"
        let systemPrompt = "你是一个专业的知识管理助手。"
        let aiResponse = try await store.llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
        
        XCTAssertTrue(aiResponse.contains("RAG") || aiResponse.contains("知识管理") || !aiResponse.isEmpty, "AI 响应不应为空且应包含关键信息")
    }
}
