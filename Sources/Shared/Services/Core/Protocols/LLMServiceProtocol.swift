// any LLMServiceProtocol.swift
//
// 作者: Wang Chong
// 功能说明: 通用生成接口
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine

// MARK: - LLM 对话服务协议 (核心推理与对话)

@MainActor
protocol LLMChatServiceProtocol: AnyObject, Sendable {
    var objectWillChange: ObservableObjectPublisher { get }
    var isProcessing: Bool { get }
    var isEnabled: Bool { get }

    // MARK: - 核心对话与推理
    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage
    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error>

    /// 通用生成接口
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - systemPrompt: 可选的系统提示词
    func generate(prompt: String, systemPrompt: String) async throws -> String
}

// MARK: - LLM 知识维护服务协议

@MainActor
protocol LLMKnowledgeServiceProtocol: AnyObject, Sendable {
    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String]
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion]
}

// MARK: - LLM 检索增强服务协议

@MainActor
protocol LLMRetrievalServiceProtocol: AnyObject, Sendable {
    func rewriteQuery(_ query: String) async -> String
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage]
}

// MARK: - LLM 服务组合协议

/// 继承所有子协议，保持向后兼容
@MainActor
protocol LLMServiceProtocol: ObservableObject, LLMChatServiceProtocol, LLMKnowledgeServiceProtocol, LLMRetrievalServiceProtocol {}
