import XCTest
@testable import KM

/// 系统集成测试：全链路 RAG 管道
/// 覆盖：导入 -> 向量化 -> 检索 -> AI 总结
@MainActor
final class RAGPipelineTests: XCTestCase {
    var store: KMStore!

    override func setUp() {
        super.setUp()
        store = KMStore() // 使用内存或测试数据库
    }

    func testFullRAGPipeline() async throws {
        // 1. 导入 (Ingest)
        let testContent = "智元 (ZhiYuan) 是一款基于 RAG 架构的知识管理软件，支持双向链接。"
        let page = store.ingestService.ingestRawContent(title: "智元简介", content: testContent, pageStore: store.sqliteStore)
        let pageID = page.id

        // 2. 向量化验证 (Vectorization)
        // 等待异步向量化完成
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let embedding = store.sqliteStore.embeddingManager.allEmbeddings[pageID]
        XCTAssertNotNil(embedding, "向量化任务应在导入后异步完成")

        // 3. 检索 (Hybrid Search)
        let searchResults = await store.linkService.search(query: "什么是智元", in: store.pages)
        XCTAssertTrue(searchResults.contains(where: { $0.id == pageID }), "混合检索应能根据语义召回导入的内容")

        // 4. AI 总结 (Generation)
        let prompt = "根据已知内容回答：智元的特点是什么？"
        let aiResponse = try await store.llmService.generate(prompt: prompt, systemPrompt: "")

        XCTAssertTrue(aiResponse.contains("RAG") || aiResponse.contains("知识管理"), "AI 总结应包含召回上下文中的关键信息")
    }
}
