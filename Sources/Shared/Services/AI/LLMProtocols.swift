// LLMProtocols.swift
//
// 作者: Wang Chong
// 功能说明: AI 模型适配器协议
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// AI 模型适配器协议
/// 允许系统在本地模型 (Ollama/Llama) 与云端 API (OpenAI/Claude) 之间无缝切换。
protocol LLMAdapter: Sendable {
    var id: String { get }
    var displayName: String { get }
    
    /// 执行同步生成任务
    func generate(prompt: String, systemPrompt: String) async throws -> String
    
    /// 执行流式生成任务
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error>
}

/// AI 任务上下文信息
struct LLMTaskContext: Sendable {
    let query: String
    let relevantPages: [WikiPage]
    let systemPrompt: String
}
