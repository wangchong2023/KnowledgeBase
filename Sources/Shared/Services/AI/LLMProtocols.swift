import Foundation

/// AI 模型适配器协议
/// 允许系统在本地模型 (Ollama/Llama) 与云端 API (OpenAI/Claude) 之间无缝切换。
protocol LLMAdapter {
    var id: String { get }
    var displayName: String { get }
    
    /// 执行同步生成任务
    func generate(prompt: String, systemPrompt: String) async throws -> String
    
    /// 执行流式生成任务
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error>
}

/// AI 任务上下文信息
struct LLMTaskContext {
    let query: String
    let relevantPages: [WikiPage]
    let systemPrompt: String
}
