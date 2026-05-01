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
    
    /// 生成最近一周的知识洞察
    func generateWeeklyInsight(pages: [WikiPage], llmService: LLMService) async throws -> WeeklyInsight {
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let newPages = pages.filter { $0.created >= lastWeek }
        let newTitles = newPages.map { $0.title }.joined(separator: ", ")
        
        let prompt = """
        # Role: 资深知识架构师与认知分析专家
        
        # Context: 
        用户在过去一周内向个人知识库添加了以下核心节点：[\(newTitles)]。
        
        # Task:
        基于上述增量数据，通过语义关联分析，生成一份高价值的《周度知识资产审计报告》。
        
        # Output Dimensions (必须包含):
        1. **认知锚点**: 识别本周知识增长的“第一性原理”或核心领域。
        2. **关联密度**: 评估新旧知识之间是否产生了语义碰撞，是否正在从“离散信息”向“网状结构”演进。
        3. **盲区预警**: 基于当前新增倾向，指出用户可能忽视的相关领域或逻辑链缺口。
        4. **行动指令**: 推荐一个具体的“跨学科”联想任务。
        
        # Constraints:
        - 语气：冷静、理性、富有洞察力（类似《经济学人》）。
        - 语言：简体中文。
        - 长度：严格控制在 250 字以内。
        """
        
        let summary = try await llmService.generate(prompt: prompt, temperature: 0.7)
        
        // 简单提取关键词 (这里可以使用 NLTagger 进一步优化)
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
