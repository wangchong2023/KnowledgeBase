import Foundation

class PromptService: ObservableObject {
    static let shared = PromptService()
    
    @Published var mindmapPrompt: String
    @Published var quizPrompt: String
    @Published var slidesPrompt: String
    @Published var reportPrompt: String
    
    private let defaults = UserDefaults.standard
    
    struct Keys {
        static let mindmap = "prompt_mindmap"
        static let quiz = "prompt_quiz"
        static let slides = "prompt_slides"
        static let report = "prompt_report"
    }
    
    init() {
        self.mindmapPrompt = defaults.string(forKey: Keys.mindmap) ?? DefaultPrompts.mindmap
        self.quizPrompt = defaults.string(forKey: Keys.quiz) ?? DefaultPrompts.quiz
        self.slidesPrompt = defaults.string(forKey: Keys.slides) ?? DefaultPrompts.slides
        self.reportPrompt = defaults.string(forKey: Keys.report) ?? DefaultPrompts.report
    }
    
    func save() {
        defaults.set(mindmapPrompt, forKey: Keys.mindmap)
        defaults.set(quizPrompt, forKey: Keys.quiz)
        defaults.set(slidesPrompt, forKey: Keys.slides)
        defaults.set(reportPrompt, forKey: Keys.report)
    }
    
    func reset() {
        mindmapPrompt = DefaultPrompts.mindmap
        quizPrompt = DefaultPrompts.quiz
        slidesPrompt = DefaultPrompts.slides
        reportPrompt = DefaultPrompts.report
        save()
    }
}

struct DefaultPrompts {
    static let mindmap = """
    # Role: 知识建模专家
    # Task: 将内容转化为 Mermaid 思维导图。
    # Requirements:
    1. 节点层级清晰。
    2. 仅返回代码块内容。
    """
    
    static let quiz = """
    # Role: 资深教育专家
    # Task: 基于以下内容生成一套结构化的知识测验 JSON。
    # Output Format (JSON ONLY):
    {
      "title": "测验标题",
      "questions": [
        {
          "id": 1,
          "text": "问题内容",
          "options": ["A...", "B...", "C...", "D..."],
          "answer": 0,
          "explanation": "答案解析"
        }
      ]
    }
    # Requirements:
    1. 包含 3-5 道单选题。
    2. 仅返回 JSON 字符串。
    """
    
    static let slides = """
    # Role: 专业演讲教练
    # Task: 将内容转化为带引用的演示文稿大纲（幻灯片格式）。
    # Requirements:
    1. 使用 Markdown 分隔符 `---` 表示换页。
    2. 每页包含标题和 3-5 个核心要点。
    3. **必须标注来源**：每个要点后使用 `[[Source]]` 标记。
    """
    
    static let report = """
    # Role: 行业分析师
    # Task: 基于以下素材撰写一份深度总结报告。
    # Requirements:
    1. 包含背景、核心洞察、风险点、结论建议。
    2. **必须包含引用溯源**：在每个核心论点后使用 `[[Source]]` 标记。
    """
}
