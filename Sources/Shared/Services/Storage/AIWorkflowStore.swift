// AIWorkflowStore.swift
//
// 作者: Wang Chong
// 功能说明: AI 工作流存储，管理 AI 扫描状态、洞察及建议。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Observation

/// AI 工作流存储，管理 AI 扫描状态、洞察及建议。
@MainActor
@Observable
final class AIWorkflowStore {
    // ── 扫描与分析状态 ──
    var isScanningAI = false
    var refactorSuggestions: [RefactorSuggestion] = []
    var potentialLinks: [PotentialLinkSuggestion] = []
    
    // ── 洞察与报告 ──
    var weeklyInsight: KnowledgeInsightService.WeeklyInsight?
    var dailyRecap: KnowledgeInsightService.DailyRecap?
    var isGeneratingDailyRecap = false
    
    // ── 页面级 AI 状态 ──
    var activePageAIResult: String?
    var isProcessingPageAI = false
    var activeQuiz: QuizModel?
    
    // ── 健康度状态 ──
    var lastLintScore: Int = 0
    var lastLintDate: Date?

    // ── 健康度代理 (由 LintService 实时计算) ──
    var healthMetrics: (score: Int, level: LintService.HealthLevel) {
        lintService.calculateHealthMetrics(issues: lintIssues)
    }
    var lintScore: Int { healthMetrics.score }
    var healthLevel: LintService.HealthLevel { healthMetrics.level }

    // ── 健康度问题存储 (Lint Issues) ──
    @ObservationIgnored private var _lintIssues: [LintIssue] = {
        if let data = UserDefaults.standard.data(forKey: "lastLintIssues"),
           let decoded = try? JSONDecoder().decode([LintIssue].self, from: data) {
            return decoded
        }
        return []
    }()
    
    var lintIssues: [LintIssue] {
        get { access(keyPath: \.lintIssues); return _lintIssues }
        set {
            withMutation(keyPath: \.lintIssues) {
                _lintIssues = newValue
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: "lastLintIssues")
                }
            }
        }
    }

    @ObservationIgnored @Inject private var insightService: KnowledgeInsightService
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject private var sqliteStore: SQLiteStore
    @ObservationIgnored @Inject private var lintService: LintService
    @ObservationIgnored @Inject private var logService: any LogServiceProtocol
    @ObservationIgnored @Inject private var linkService: LinkService

    init() {}
    
    // ── AI 洞察管理 ──

    func generateWeeklyInsight(forceRefresh: Bool = false) async {
        guard llmService.isEnabled else { return }

        if !forceRefresh, let cached = loadCachedWeeklyInsight() {
            weeklyInsight = cached
            return
        }

        do {
            let insight = try await insightService.generateWeeklyInsight(pages: sqliteStore.pages, llmService: llmService)
            weeklyInsight = insight
            saveCachedWeeklyInsight(insight)
        } catch {
            logService.addLog(action: .error, target: "AIWorkflowStore", details: "Weekly Insight Error: \(error.localizedDescription)")
        }
    }

    private func weeklyCacheKey() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let lang = Localized.currentLanguage
        return "weekly_insight_\(components.yearForWeekOfYear ?? 0)_\(components.weekOfYear ?? 0)_\(lang)"
    }

    private func loadCachedWeeklyInsight() -> KnowledgeInsightService.WeeklyInsight? {
        let key = weeklyCacheKey()
        guard let data = UserDefaults.standard.data(forKey: key),
              let insight = try? JSONDecoder().decode(KnowledgeInsightService.WeeklyInsight.self, from: data) else {
            return nil
        }
        return insight
    }

    private func saveCachedWeeklyInsight(_ insight: KnowledgeInsightService.WeeklyInsight) {
        let key = weeklyCacheKey()
        if let data = try? JSONEncoder().encode(insight) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func generateDailyRecap(forceRefresh: Bool = false) async {
        guard !isGeneratingDailyRecap else { return }
        guard llmService.isEnabled else { return }
        
        isGeneratingDailyRecap = true
        defer { isGeneratingDailyRecap = false }
        
        do {
            let result = try await insightService.generateDailyRecap(
                pages: sqliteStore.pages, 
                llmService: llmService, 
                forceRefresh: forceRefresh
            )
            dailyRecap = result
        } catch {
            logService.addLog(action: .error, target: "AIWorkflowStore", details: "Generate daily recap failed: \(error.localizedDescription)")
        }
    }

    // ── 扫描与健康检查逻辑 ──

    func runLint() async {
        let taskID = TaskCenter.shared.addTask(type: .healthCheck, name: Localized.tr("sidebar.healthCheck"), target: "System")
        let issues = await lintService.runLint(pages: sqliteStore.pages, linkService: linkService)
        lintIssues = issues
        lastLintDate = Date()
        TaskCenter.shared.updateTask(taskID, status: .completed)
    }

    func runAIScan() async {
        guard llmService.isEnabled else { 
            logService.addLog(action: .aiscanSkipped, target: "System", details: "LLM service disabled")
            return 
        }
        
        isScanningAI = true
        let taskID = TaskCenter.shared.addTask(type: .ai, name: L10n.AI.Task.tr("scanTaskName"), target: "System")
        
        do {
            let samplePages = Array(sqliteStore.pages.prefix(10))
            let suggestions = try await llmService.analyzeForRefactoring(pages: samplePages)
            
            let activePages = sqliteStore.pages.sorted(by: { $0.updated > $1.updated }).prefix(5)
            let existingTitles = sqliteStore.pages.map { $0.title }
            
            var tempLinks: [PotentialLinkSuggestion] = []
            var seenLinks = Set<String>()
            for page in activePages {
                let found = try await llmService.discoverPotentialLinks(content: page.content, existingTitles: existingTitles)
                for title in Set(found) {
                    let linkKey = "\(page.id.uuidString)-\(title)"
                    if !seenLinks.contains(linkKey) && !page.content.contains("[[\(title)]]") {
                        seenLinks.insert(linkKey)
                        tempLinks.append(PotentialLinkSuggestion(sourcePageID: page.id, sourceTitle: page.title, targetTitle: title))
                    }
                }
            }
            
            refactorSuggestions = suggestions
            potentialLinks = tempLinks
            isScanningAI = false
            TaskCenter.shared.updateTask(taskID, status: .completed)
        } catch {
            logService.addLog(action: .aiscanFailed, target: "System", details: error.localizedDescription)
            isScanningAI = false 
            TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
        }
    }

    func fetchFixSuggestion(for issue: LintIssue) async throws -> String {
        HapticManager.shared.trigger(.selection)
        return try await AISynthesisService.shared.suggestFix(issue: issue, pages: sqliteStore.pages)
    }

    /// 查找与当前页面语义相似的页面（基于向量嵌入）
    func findSimilarPages(for page: WikiPage, limit: Int = 3) -> [WikiPage] {
        let results = sqliteStore.embeddingManager.search(query: page.title, topK: limit + 1)
        return results
            .filter { $0.id != page.id }
            .prefix(limit)
            .compactMap { res in sqliteStore.pages.first { $0.id == res.id } }
    }

    // ── 页面级 AI 行为 ──

    func runPageAISummary(content: String) {
        ToastManager.shared.show(type: .processing, message: L10n.Common.tr("aiThinking"), duration: 0)
        Task {
            isProcessingPageAI = true
            defer { 
                isProcessingPageAI = false 
                ToastManager.shared.dismiss()
            }
            do {
                let summary = try await AISynthesisService.shared.summarize(content: content)
                activePageAIResult = summary
                HapticManager.shared.trigger(.success)
            } catch {
                ToastManager.shared.show(type: .error, message: error.localizedDescription)
            }
        }
    }

    func extractPageActions(content: String) {
        ToastManager.shared.show(type: .processing, message: L10n.Common.tr("aiThinking"), duration: 0)
        Task {
            isProcessingPageAI = true
            defer { 
                isProcessingPageAI = false 
                ToastManager.shared.dismiss()
            }
            do {
                let actions = try await AISynthesisService.shared.extractActions(content: content)
                activePageAIResult = actions
                HapticManager.shared.trigger(.success)
            } catch {
                ToastManager.shared.show(type: .error, message: error.localizedDescription)
            }
        }
    }

    func performPageSynthesis(type: SynthesisStore.SynthesisType, title: String, content: String) {
        let taskID = TaskCenter.shared.addTask(type: .ai, name: type.title, target: title)
        ToastManager.shared.show(type: .processing, message: L10n.Common.tr("aiThinking"), duration: 0)

        Task {
            isProcessingPageAI = true
            defer {
                isProcessingPageAI = false
                ToastManager.shared.dismiss()
            }
            do {
                let result: String
                switch type {
                case .mindmap: result = try await AISynthesisService.shared.generateMindMap(content: content)
                case .quiz: result = try await AISynthesisService.shared.generateQuiz(content: content)
                case .slides: result = try await AISynthesisService.shared.generatePresentation(content: content)
                case .report: result = try await AISynthesisService.shared.generateReport(content: content)
                case .infographic: result = try await AISynthesisService.shared.generateInfographic(content: content)
                }
                TaskCenter.shared.updateTask(taskID, status: .completed)
                if type == .quiz {
                    if let data = result.data(using: .utf8),
                       let quiz = try? JSONDecoder().decode(QuizModel.self, from: data) {
                        activeQuiz = quiz
                    } else {
                        activePageAIResult = result
                    }
                } else {
                    activePageAIResult = result
                }
                HapticManager.shared.trigger(.success)
            } catch {
                TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                ToastManager.shared.show(type: .error, message: error.localizedDescription)
            }
        }
    }

    func clearAll() {
        refactorSuggestions = []
        potentialLinks = []
        weeklyInsight = nil
        dailyRecap = nil
        activePageAIResult = nil
        activeQuiz = nil
        lintIssues = []
        lastLintScore = 0
        lastLintDate = nil
    }

    // ── 建议清理方法 ──
    func removePotentialLink(id: UUID) {
        potentialLinks.removeAll { $0.id == id }
    }

    func removeRefactorSuggestion(id: String) {
        refactorSuggestions.removeAll { $0.id == id }
    }

}
