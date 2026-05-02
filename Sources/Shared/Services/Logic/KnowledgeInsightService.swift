import Foundation

/// 知识见解服务 (PM 视角：价值闭环)
/// 负责生成知识周报与核心趋势分析。@MainActor
final class KnowledgeInsightService: @unchecked Sendable {
    
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
    
    /// 生成每日主动召回见解 (Smart Recall)
    /// 逻辑：根据用户最近 3 天关注的内容，寻找 30-90 天前编辑过且语义相关的“尘封内容”，触发知识复利。
    func generateDailyRecap(pages: [WikiPage], llmService: any LLMServiceProtocol) async throws -> DailyRecap {
        guard pages.count > 1 else { throw NSError(domain: "Insight", code: -1) }
        
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 定义“最近”和“长程”时间范围
        let recentThreshold = calendar.date(byAdding: .day, value: -3, to: now)!
        let longTermMin = calendar.date(byAdding: .day, value: -90, to: now)!
        let longTermMax = calendar.date(byAdding: .day, value: -30, to: now)!
        
        // 2. 获取最近感兴趣的主题（模拟，实际可从 NavigationHistory 获取）
        let recentPages = pages.filter { $0.updated >= recentThreshold }
        let recentFocus = recentPages.map { $0.title }.joined(separator: " ")
        
        // 3. 寻找长程页面
        let candidates = pages.filter { $0.updated >= longTermMin && $0.updated <= longTermMax }
        guard !candidates.isEmpty else {
            // 如果没有合适范围的，回退到普通召回
            return try await generateSimpleRecap(pages: pages, llmService: llmService)
        }
        
        // 4. 这里的简化逻辑：随机选一个（理想应使用 Embedding 语义匹配）
        let target = candidates.randomElement()!
        
        let prompt = """
        # Role: 深度学习导师
        # Task: 帮助用户建立新旧知识之间的“长程连接”。
        # Current Focus: \(recentFocus)
        # Recall Page Title: \(target.title)
        # Recall Content: \(target.content.prefix(500))
        # Requirements: 分析为什么现在复习这个页面对当前的研究有帮助。
        返回 JSON 格式: {"insight": "...", "suggestedConnection": "..."}
        """
        
        let response = try await llmService.generate(prompt: prompt, systemPrompt: "你是一个深度学习导师，擅长帮助用户建立跨时空的知识连接。")
        let data = response.data(using: .utf8)!
        let json = try JSONDecoder().decode([String: String].self, from: data)
        
        return DailyRecap(
            targetPageTitle: target.title,
            insight: json["insight"] ?? "",
            suggestedConnection: json["suggestedConnection"] ?? ""
        )
    }
    
    private func generateSimpleRecap(pages: [WikiPage], llmService: any LLMServiceProtocol) async throws -> DailyRecap {
        let sorted = pages.sorted { $0.updated < $1.updated }
        let target = sorted.first!
        let prompt = "分析页面内容并提供复习见解: \(target.title)\n\(target.content.prefix(300))"
        let response = try await llmService.generate(prompt: prompt, systemPrompt: "你是一个知识导师。")
        return DailyRecap(targetPageTitle: target.title, insight: response, suggestedConnection: "定期复习是巩固知识的关键。")
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
        
        let summary = try await llmService.generate(prompt: prompt, systemPrompt: "你是一个资深知识架构师，擅长总结知识体系。")
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
