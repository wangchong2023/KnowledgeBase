// KnowledgeInsightService.swift
//
// 作者: Wang Chong
// 功能说明: 知识见解服务 (PM 视角：价值闭环)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
    /// 每天仅生成一次，结果缓存至 UserDefaults。用户手动刷新时跳过缓存。
    func generateDailyRecap(pages: [WikiPage], llmService: any LLMServiceProtocol, forceRefresh: Bool = false) async throws -> DailyRecap {
        guard pages.count > 1 else { throw NSError(domain: "Insight", code: -1) }

        if !forceRefresh, let cached = loadCachedDailyRecap() {
            return cached
        }

        let now = Date()
        let calendar = Calendar.current
        let recentThreshold = calendar.date(byAdding: .day, value: -3, to: now)!
        let longTermMin = calendar.date(byAdding: .day, value: -90, to: now)!
        let longTermMax = calendar.date(byAdding: .day, value: -30, to: now)!

        let recentPages = pages.filter { $0.updated >= recentThreshold }
        let recentFocus = recentPages.map { $0.title }.joined(separator: " ")

        let candidates = pages.filter { $0.updated >= longTermMin && $0.updated <= longTermMax }
        let recap: DailyRecap
        if !candidates.isEmpty {
            let target = candidates.randomElement()!
            let prompt = Localized.trf("insight.daily.prompt.recent", recentFocus, target.title, String(target.content.prefix(500)))
            let response = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Dashboard.tr("insight.daily.systemPrompt"))
            let data = response.data(using: .utf8)!
            let json = try JSONDecoder().decode([String: String].self, from: data)
            recap = DailyRecap(
                targetPageTitle: target.title,
                insight: json["insight"] ?? "",
                suggestedConnection: json["suggestedConnection"] ?? ""
            )
        } else {
            let sorted = pages.sorted { $0.updated < $1.updated }
            let target = sorted.first!
            let prompt = Localized.trf("insight.daily.prompt.oldest", target.title, String(target.content.prefix(300)))
            let response = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Dashboard.tr("insight.daily.systemPrompt"))
            recap = DailyRecap(targetPageTitle: target.title, insight: response, suggestedConnection: L10n.Dashboard.tr("insight.recap.tip"))
        }

        saveCachedDailyRecap(recap)
        return recap
    }

    private func cacheKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let lang = Localized.currentLanguage
        return "daily_recap_\(formatter.string(from: Date()))_\(lang)"
    }

    private func loadCachedDailyRecap() -> DailyRecap? {
        let key = cacheKey()
        guard let data = UserDefaults.standard.data(forKey: key),
              let recap = try? JSONDecoder().decode(DailyRecap.self, from: data) else {
            return nil
        }
        return recap
    }

    private func saveCachedDailyRecap(_ recap: DailyRecap) {
        let key = cacheKey()
        if let data = try? JSONEncoder().encode(recap) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// 生成最近一周的知识洞察
    func generateWeeklyInsight(pages: [WikiPage], llmService: any LLMServiceProtocol) async throws -> WeeklyInsight {
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let newPages = pages.filter { $0.created >= lastWeek }
        let newTitles = newPages.map { $0.title }.joined(separator: ", ")
        
        let prompt = Localized.trf("insight.weekly.prompt", newTitles)
        
        let summary = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Dashboard.tr("insight.weekly.systemPrompt"))
        let keywords = Array(newPages.flatMap { $0.tags }.prefix(5))
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: Localized.currentLanguage)
        let dateRange = "\(formatter.string(from: lastWeek)) - \(formatter.string(from: Date()))"
        
        return WeeklyInsight(
            dateRange: dateRange,
            totalNewPages: newPages.count,
            topKeywords: keywords,
            aiSummary: summary,
            growthTraction: newPages.count > 5 ? L10n.Dashboard.tr("insight.growth.explosive") : L10n.Dashboard.tr("insight.growth.steady")
        )
    }
}
