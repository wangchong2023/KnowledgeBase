// PromptService.swift
//
// 作者: Wang Chong
// 功能说明: [L2] 领域服务：统一 Prompt 资产管理中心
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// [L2] 领域服务：统一 Prompt 资产管理中心
/// 实现提示词与逻辑代码的解耦，便于后续调优与多语言适配。
final class PromptService: ObservableObject, @unchecked Sendable {
    static let shared = PromptService()
    
    private init() {
        reload()
    }
    
    private func load() {
        let defaults = UserDefaults.standard
        if let savedMindmap = defaults.string(forKey: "prompt_mindmap") { self.mindmapPrompt = savedMindmap }
        if let savedQuiz = defaults.string(forKey: "prompt_quiz") { self.quizPrompt = savedQuiz }
        if let savedSlides = defaults.string(forKey: "prompt_slides") { self.slidesPrompt = savedSlides }
        if let savedReport = defaults.string(forKey: "prompt_report") { self.reportPrompt = savedReport }
    }
    
    // MARK: - 检索增强 (RAG) 相关
    
    @Published var queryRewritePrompt: String = Localized.tr("prompt.queryRewrite")
    
    @Published var rerankPrompt: String = Localized.tr("prompt.rerank")
    
    // MARK: - 知识维护相关
    
    @Published var potentialLinksPrompt: String = Localized.tr("prompt.potentialLinks")
    
    @Published var foldingPrompt: String = Localized.tr("prompt.folding")
    
    @Published var refactorPrompt: String = Localized.tr("prompt.refactor")
    
    // MARK: - 知识合成 (Synthesis) 相关
    
    @Published var fixSuggestionPrompt: String = Localized.tr("prompt.fixSuggestion")

    @Published var mindmapPrompt: String = Localized.tr("prompt.default.mindmap")
    @Published var quizPrompt: String = Localized.tr("prompt.default.quiz")
    @Published var slidesPrompt: String = Localized.tr("prompt.default.slides")
    @Published var summaryPrompt: String = Localized.tr("prompt.default.summary")
    @Published var actionPrompt: String = Localized.tr("prompt.default.actions")
    @Published var infographicPrompt: String = Localized.tr("prompt.default.infographic")
    @Published var insightQuestionsPrompt: String = Localized.tr("prompt.default.insightQuestions")
    @Published var reportPrompt: String = Localized.tr("prompt.default.report")

    // MARK: - 用户资产
    
    @Published var userShortcuts: [ShortcutItem] = []
    
    func updateLocalizables() {
        userShortcuts = [
            ShortcutItem(text: Localized.tr("prompt.shortcut.deepReview")),
            ShortcutItem(text: Localized.tr("prompt.shortcut.findGaps")),
            ShortcutItem(text: Localized.tr("prompt.shortcut.studyPath"))
        ]
        
        // 刷新其他提示词
        queryRewritePrompt = Localized.tr("prompt.queryRewrite")
        rerankPrompt = Localized.tr("prompt.rerank")
        potentialLinksPrompt = Localized.tr("prompt.potentialLinks")
        foldingPrompt = Localized.tr("prompt.folding")
        refactorPrompt = Localized.tr("prompt.refactor")
        fixSuggestionPrompt = Localized.tr("prompt.fixSuggestion")
        
        // 默认提示词（如果没有保存过）
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "prompt_mindmap") == nil { mindmapPrompt = Localized.tr("prompt.default.mindmap") }
        if defaults.string(forKey: "prompt_quiz") == nil { quizPrompt = Localized.tr("prompt.default.quiz") }
        if defaults.string(forKey: "prompt_slides") == nil { slidesPrompt = Localized.tr("prompt.default.slides") }
        if defaults.string(forKey: "prompt_report") == nil { reportPrompt = Localized.tr("prompt.default.report") }
    }
    
    func reload() {
        load()
        updateLocalizables()
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(mindmapPrompt, forKey: "prompt_mindmap")
        defaults.set(quizPrompt, forKey: "prompt_quiz")
        defaults.set(slidesPrompt, forKey: "prompt_slides")
        defaults.set(reportPrompt, forKey: "prompt_report")
        print("Prompt configurations saved to UserDefaults.")
    }
    
    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "prompt_mindmap")
        defaults.removeObject(forKey: "prompt_quiz")
        defaults.removeObject(forKey: "prompt_slides")
        defaults.removeObject(forKey: "prompt_report")
        
        self.mindmapPrompt = Localized.tr("prompt.default.mindmap")
        self.quizPrompt = Localized.tr("prompt.default.quiz")
        self.slidesPrompt = Localized.tr("prompt.default.slides")
        self.reportPrompt = Localized.tr("prompt.default.report")
        print("Prompt configurations reset to default.")
    }
    
    /// 根据当前界面语言生成的 AI 回复指令
    var languageInstruction: String {
        if Localized.isChinese {
            return "\n\n请使用中文回复。"
        } else {
            return "\n\nPlease reply in English."
        }
    }
}

/// 快捷指令模型
struct ShortcutItem: Identifiable, Equatable {
    let id = UUID()
    var text: String
}
