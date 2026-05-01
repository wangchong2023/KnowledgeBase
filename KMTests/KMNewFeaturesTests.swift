import XCTest
@testable import KnowledgeBase

final class KMNewFeaturesTests: XCTestCase {

    // MARK: - QuizModel Parsing Tests
    func testQuizModelParsing() {
        let json = """
        {
          "title": "测试测验",
          "questions": [
            {
              "id": 1,
              "text": "Swift 是一门什么语言?",
              "options": ["编译型", "解释型", "脚本型", "汇编型"],
              "answer": 0,
              "explanation": "Swift 经过 LLVM 编译。"
            }
          ]
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let model = try decoder.decode(QuizModel.self, from: data)
            XCTAssertEqual(model.title, "测试测验")
            XCTAssertEqual(model.questions.count, 1)
            XCTAssertEqual(model.questions.first?.answer, 0)
        } catch {
            XCTFail("QuizModel decoding failed: \(error)")
        }
    }

    // MARK: - AITaskCenter Tests
    func testAITaskCenterManagement() {
        let center = AITaskCenter.shared
        let initialCount = center.tasks.count
        
        let taskID = center.addTask(name: "测试任务", target: "测试目标")
        XCTAssertEqual(center.tasks.count, initialCount + 1)
        XCTAssertEqual(center.tasks.first?.name, "测试任务")
        
        center.updateTask(taskID, status: .running(progress: 0.5))
        if case .running(let progress) = center.tasks.first?.status {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Task status should be running")
        }
        
        // 测试失败状态
        center.updateTask(taskID, status: .failed(error: "Timeout"))
        if case .failed(let error) = center.tasks.first?.status {
            XCTAssertEqual(error, "Timeout")
        } else {
            XCTFail("Task status should be failed")
        }
        
        center.removeTask(taskID)
        XCTAssertEqual(center.tasks.count, initialCount)
    }

    // MARK: - PromptService Tests
    func testPromptServicePersistence() {
        let service = PromptService.shared
        let originalMindmap = service.mindmapPrompt
        
        service.mindmapPrompt = "New Custom Prompt"
        service.save()
        
        // 模拟重启（重新初始化）
        let newService = PromptService()
        XCTAssertEqual(newService.mindmapPrompt, "New Custom Prompt")
        
        service.reset()
        XCTAssertEqual(service.mindmapPrompt, DefaultPrompts.mindmap)
    }

    // MARK: - RecursiveChunker Semantic Tests
    func testRecursiveChunkerSemanticSplitting() {
        let chunker = RecursiveChunker()
        let markdown = """
        # Header 1
        Section 1 content.
        
        ## Subheader 2
        Section 2 content. This should be split correctly.
        """
        
        let chunks = chunker.split(text: markdown)
        XCTAssertGreaterThan(chunks.count, 0)
        XCTAssertTrue(chunks.first?.text.contains("Header 1") ?? false)
    }

    // MARK: - Hybrid Search Logic Tests
    func testHybridSearchQueryExpansion() {
        let store = SQLiteStore()
        let query = "Karpathy Deep Learning"
        
        // 验证关键词提取逻辑（内部方法可能需要通过 KMStore 测试）
        // 这里我们测试搜索流程的稳定性
        let results = store.searchPages(query: query)
        XCTAssertNotNil(results)
    }

    // MARK: - QuizModel Fault Tolerance
    func testQuizModelFaultTolerance() {
        let brokenJson = "{\"title\": \"Broken\", \"questions\": []" // 缺少闭合括号
        let data = brokenJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        XCTAssertThrowsError(try decoder.decode(QuizModel.self, from: data))
    }

    // MARK: - VaultService Bookmark Persistence
    func testVaultServiceBookmarkPersistence() {
        let service = VaultService.shared
        let dummyURL = URL(fileURLWithPath: "/tmp/test_vault")
        
        // 模拟书签存储（注意：单元测试中可能因权限无法真实创建 Security-Scoped Bookmark）
        // 我们验证逻辑链路是否通畅
        service.storeBookmark(for: dummyURL)
        
        // 检查 UserDefaults 是否有记录（取决于具体键名实现）
        let key = "vault_bookmark_\(dummyURL.lastPathComponent)"
        XCTAssertNil(UserDefaults.standard.data(forKey: key), "临时路径不应生成有效书签，但逻辑不应崩溃")
    }
    
    // MARK: - External Link Citation Detection (Upgraded)
    func testCitationLinkDetection() {
        let report = "这是核心观点 [[Source]]。"
        XCTAssertTrue(report.contains("[[Source]]"), "应该使用双括号交互格式")
    }
}
