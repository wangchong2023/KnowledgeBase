import Foundation

/// [L2] 领域服务：统一 Prompt 资产管理中心
/// 实现提示词与逻辑代码的解耦，便于后续调优与多语言适配。
final class PromptService: ObservableObject {
    static let shared = PromptService()
    
    private init() {}
    
    // MARK: - 检索增强 (RAG) 相关
    
    @Published var queryRewritePrompt: String = """
        你是一位知识检索专家。请分析以下查询并改写为一组检索关键词。
        要求：
        1. 扩充同义词和专业术语。
        2. 仅输出关键词，逗号分隔。
        """
    
    @Published var rerankPrompt: String = """
        # Role: 信息检索专家
        # Task: 根据相关性对以下文档排序。
        
        # Requirements:
        仅返回 JSON 数组格式的排序索引，如: [1, 0, 2]。不要解释。
        格式: {"ranked_ids": [...]}
        """
    
    // MARK: - 知识维护相关
    
    @Published var potentialLinksPrompt: String = """
        你是一位专业的知识库架构师。
        任务：分析给定的文本，识别其中提到的、但尚未标记为 [[链接]] 的现有页面标题。
        
        要求：
        1. 仅返回文本中明确提到或高度相关的标题。
        2. 以 JSON 数组格式返回，例如: ["标题1", "标题2"]
        3. 不要返回任何解释。
        """
    
    @Published var foldingPrompt: String = """
        你是一位知识维护专家。请将以下“新资料”增量式地融合（Fold）进“现有页面内容”中。
        
        要求：
        1. 保持页面结构的完整性。
        2. 逻辑去重，增量插入。
        3. 保持双向链接 [[WikiLinks]]。
        4. 直接返回最终的 Markdown。
        """
    
    @Published var refactorPrompt: String = """
        你是一位知识管理专家。分析页面数据，寻找优化结构的机会（合并相似、拆分过大、重命名）。
        以 JSON 数组格式返回，对象包含: type, target, reason, suggestion。
        """
    
    // MARK: - 知识合成 (Synthesis) 相关
    
    @Published var fixSuggestionPrompt: String = """
        针对知识库健康检查问题提供修复建议。
        仅以简洁的中文给出 2-3 行操作步骤，不要废话。
        """

    @Published var mindmapPrompt: String = "请根据以下内容生成一个 Mermaid 格式的思维导图（mindmap）。直接输出代码块。"
    @Published var quizPrompt: String = "请根据以下内容生成 3 道选择题和 1 道简答题，用于知识测验。使用 Markdown 格式。"
    @Published var slidesPrompt: String = "请将以下内容转化为演示文稿大纲（Markdown Slides），每页大纲用 --- 分隔。"
    @Published var reportPrompt: String = "请基于以下内容生成一份深度的分析报告。包含：核心摘要、现状分析、挑战与对策、结论建议。"

    // MARK: - 用户资产
    
    @Published var userShortcuts: [ShortcutItem] = [
        ShortcutItem(text: "深度复盘我的核心概念"),
        ShortcutItem(text: "找出知识库中的逻辑断层"),
        ShortcutItem(text: "为我生成本周的学习路径")
    ]
    
    func save() {
        // 实现持久化逻辑（此处简略，实际可存入 UserDefaults）
        print("Prompt configurations saved.")
    }
    
    func reset() {
        // 恢复出厂设置逻辑
        self.mindmapPrompt = "请根据以下内容生成一个 Mermaid 格式的思维导图（mindmap）。直接输出代码块。"
        self.quizPrompt = "请根据以下内容生成 3 道选择题和 1 道简答题，用于知识测验。使用 Markdown 格式。"
        self.slidesPrompt = "请将以下内容转化为演示文稿大纲（Markdown Slides），每页大纲用 --- 分隔。"
        self.reportPrompt = "请基于以下内容生成一份深度的分析报告。包含：核心摘要、现状分析、挑战与对策、结论建议。"
        print("Prompt configurations reset to default.")
    }
}

/// 快捷指令模型
struct ShortcutItem: Identifiable, Equatable {
    let id = UUID()
    var text: String
}
