import Foundation

/// 知识见解服务 (PM 视角：价值闭环)
/// 负责生成知识周报与核心趋势分析。
final class KnowledgeInsightService {
    
    struct WeeklyInsight: Codable, Equatable {
        let dateRange: String
        let totalNewPages: Int
        let topKeywords: [String]
        let aiSummary: String
        let growthTraction: String // 增长趋势描述
    }
    
    struct DailyRecap: Codable, Equatable {
        let targetPageTitle: String
        let insight: String
        let suggestedConnection: String
    }
    
    /// 生成每日主动召回见解 (Smart Recap)
    func generateDailyRecap(pages: [WikiPage], llmService: any LLMServiceProtocol) async throws -> DailyRecap {
        guard !pages.isEmpty else { throw NSError(domain: "Insight", code: -1) }
        
        let sorted = pages.sorted { $0.updated < $1.updated }
        let target = sorted.first!
        
        let prompt = """
        # Role: 深度学习导师
        # Task: 帮助用户重新激活记忆。
        # Page Title: \(target.title)
        # Content Snippet: \(target.content.prefix(300))
        # Requirements: 返回 JSON 格式: {"insight": "...", "suggestedConnection": "..."}
        """
        
        let response = try await llmService.generate(prompt: prompt, temperature: 0.5)
        let data = response.data(using: .utf8)!
        let json = try JSONDecoder().decode([String: String].self, from: data)
        
        return DailyRecap(
            targetPageTitle: target.title,
            insight: json["insight"] ?? "",
            suggestedConnection: json["suggestedConnection"] ?? ""
        )
    }

    /// 生成最近一周的知识洞察
    func generateWeeklyInsight(pages: [WikiPage], llmService: any LLMServiceProtocol) async throws -> WeeklyInsight {
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let newPages = pages.filter { $0.created >= lastWeek }
        let newTitles = newPages.map { $0.title }.joined(separator: ", ")
        
        let prompt = """
        # Role: 资深知识架构师
        # Context: 用户添加了节点：[\(newTitles)]。
        # Task: 生成周度报告，包含认知锚点、关联密度等。要求 250 字以内。
        """
        
        let summary = try await llmService.generate(prompt: prompt, temperature: 0.7)
        let keywords = Array(newPages.flatMap { $0.tags }.prefix(5))
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateRange = "\(formatter.string(from: lastWeek)) - \(formatter.string(from: Date()))"
        
        return WeeklyInsight(
            dateRange: dateRange,
            totalNewPages: newPages.count,
            topKeywords: keywords,
            aiSummary: summary,
            growthTraction: newPages.count > 5 ? "爆发式增长" : "稳步积累中"
        )
    }
}
