import Foundation

/// RAG 自动化评估引擎
/// 用于计算 AI 检索结果与黄金数据集的匹配度
final class RAGEvaluator {
    struct EvaluationResult {
        let score: Double
        let failedCases: [String]
    }
    
    /// 执行回归测试
    func evaluate(llmService: LLMService, store: SQLiteStore) async -> EvaluationResult {
        let goldenSetURL = Bundle.main.url(forResource: "RAG_GoldenSet", withExtension: "json")!
        let data = try! Data(contentsOf: goldenSetURL)
        let cases = try! JSONDecoder().decode([GoldenCase].self, from: data)
        
        var totalScore: Double = 0
        var failures: [String] = []
        
        for kase in cases {
            // 1. 模拟 AI 检索
            let response = await llmService.generateSummary(for: kase.document)
            
            // 2. 关键词匹配打分 (简单 NLP 逻辑)
            let matchCount = kase.expected_keywords.filter { response.contains($0) }.count
            let score = Double(matchCount) / Double(kase.expected_keywords.count)
            
            totalScore += score
            if score < 0.5 {
                failures.append(kase.id)
            }
        }
        
        return EvaluationResult(score: totalScore / Double(cases.count), failedCases: failures)
    }
}

struct GoldenCase: Codable {
    let id: String
    let document: String
    let question: String
    let expected_keywords: [String]
}
