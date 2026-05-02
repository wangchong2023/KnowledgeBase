import Foundation

/// [L2] 领域服务：统一 Prompt 资产管理中心
/// 实现提示词与逻辑代码的解耦，便于后续调优与多语言适配。
final class PromptService: ObservableObject {
    static let shared = PromptService()
    
    private init() {
        load()
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
    
    @Published var userShortcuts: [ShortcutItem] = [
        ShortcutItem(text: Localized.tr("prompt.shortcut.deepReview")),
        ShortcutItem(text: Localized.tr("prompt.shortcut.findGaps")),
        ShortcutItem(text: Localized.tr("prompt.shortcut.studyPath"))
    ]
    
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
}

/// 快捷指令模型
struct ShortcutItem: Identifiable, Equatable {
    let id = UUID()
    var text: String
}
