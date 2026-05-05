// LLMService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的核心 AI 大模型服务层（LLMService），作为系统与生成式 AI 交互的中心枢纽与编排器。
// 该服务通过高度解耦的架构设计，整合了配置管理、上下文构建、历史持久化及多协议子服务，主要功能点如下：
// 1. 多维度业务支持：实现了对话、流式响应、智能导入（Smart Ingest）、关联发现及查询重写等核心 RAG 流程。
// 2. 状态驱动与响应：通过 Combine 订阅配置变更及系统级清理事件（WikiEventBus），确保 UI 与底层服务的物理一致性。
// 3. 架构解耦：作为 facade 模式的实现，将具体任务分发至 LLMChatService、LLMRefactorService 等专项服务。
// 版本: 1.3
// 修改记录:
//   - 2026-05-05: 完整重构以实现 LLMServiceProtocol，修复功能丢失问题，集成全局清理事件。
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine
import SwiftUI

/// AI 大模型调度服务 (L1 服务层)
@MainActor
final class LLMService: ObservableObject, LLMServiceProtocol, @unchecked Sendable {
    
    static let shared = LLMService()
    
    // MARK: - UI 状态属性 (与 LLMConfigStore 同步)
    @Published var provider: LLMProvider { didSet { configStore.provider = provider } }
    @Published var apiKey: String { didSet { configStore.apiKey = apiKey } }
    @Published var baseURL: String { didSet { configStore.baseURL = baseURL } }
    @Published var model: String { didSet { configStore.model = model } }
    @Published var isEnabled: Bool { didSet { configStore.isEnabled = isEnabled } }
    @Published var autoScan: Bool { didSet { configStore.autoScan = autoScan } }
    @Published var autoRefactor: Bool { didSet { configStore.autoRefactor = autoRefactor } }
    
    // 运行时状态
    @Published var isProcessing = false
    @Published var streamingContent = ""
    @Published var chatHistory: [ChatMessage] = []
    
    var isReady: Bool {
        isEnabled && !apiKey.isEmpty
    }
    
    // MARK: - 内部组件
    private let configStore: LLMConfigStore
    private let contextBuilder: LLMContextBuilder
    private let historyStore: ChatHistoryStore
    private var refactorService: LLMRefactorService?
    private var chatService: LLMChatService?
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化
    init() {
        self.configStore = LLMConfigStore()
        self.historyStore = ChatHistoryStore()
        self.contextBuilder = LLMContextBuilder()
        
        // 从持久化配置中初始化属性
        self._provider = .init(initialValue: configStore.provider)
        self._apiKey = .init(initialValue: configStore.apiKey)
        self._baseURL = .init(initialValue: configStore.baseURL)
        self._model = .init(initialValue: configStore.model)
        self._isEnabled = .init(initialValue: configStore.isEnabled)
        self._autoScan = .init(initialValue: configStore.autoScan)
        self._autoRefactor = .init(initialValue: configStore.autoRefactor)
        
        // 加载历史消息
        self.chatHistory = historyStore.messages
        
        // 初始化专项服务
        updateSubServices()
        
        // 设置订阅与事件监听
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // 1. 同步配置存储层的变更
        configStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.configStore.provider != self.provider { self.provider = self.configStore.provider }
                if self.configStore.apiKey != self.apiKey { self.apiKey = self.configStore.apiKey }
                if self.configStore.baseURL != self.baseURL { self.baseURL = self.configStore.baseURL }
                if self.configStore.model != self.model { self.model = self.configStore.model }
                if self.configStore.isEnabled != self.isEnabled { self.isEnabled = self.configStore.isEnabled }
                if self.configStore.autoScan != self.autoScan { self.autoScan = self.configStore.autoScan }
                if self.configStore.autoRefactor != self.autoRefactor { self.autoRefactor = self.configStore.autoRefactor }
                self.updateSubServices()
            }
            .store(in: &cancellables)
            
        // 2. 订阅全局清理事件
        WikiEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.clearChatHistory()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSubServices() {
        let client = makeClient()
        self.refactorService = LLMRefactorService(client: client, model: model)
        self.chatService = LLMChatService(client: client, model: model)
    }

    private func makeClient() -> LLMClient {
        LLMClient(baseURL: baseURL, apiKey: apiKey)
    }

    // MARK: - LLMChatServiceProtocol

    func generate(prompt: String, systemPrompt: String) async throws -> String {
        guard isEnabled, !apiKey.isEmpty else { throw LLMError.notConfigured }
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        let response = try await makeClient().sendRequest(body: body)
        guard let choice = (response["choices"] as? [[String: Any]])?.first,
              let message = choice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }

    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage {
        guard isEnabled, !apiKey.isEmpty, let chatService else { throw LLMError.notConfigured }
        
        let userMessage = ChatMessage(role: .user, content: query)
        self.chatHistory.append(userMessage)
        historyStore.append(userMessage)
        
        isProcessing = true
        defer { isProcessing = false }
        
        let context = contextBuilder.buildRelevantContext(query: query, pages: pages)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
        
        let response = try await chatService.chat(systemPrompt: systemPrompt, query: query, history: Array(historyStore.recent(10)))
        let assistantMessage = ChatMessage(role: .assistant, content: response)
        
        self.chatHistory.append(assistantMessage)
        historyStore.append(assistantMessage)
        historyStore.persistToDisk()
        
        return assistantMessage
    }

    /// UI 兼容别名
    func sendChatMessage(query: String, pages: [WikiPage]) async throws {
        _ = try await chat(query: query, pages: pages)
    }

    func cancelCurrentRequest() {
        isProcessing = false
        // 实际取消逻辑需要委托给 LLMClient 的 URLSessionTask
    }

    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream(String.self) { continuation in
            Task {
                guard isEnabled, !apiKey.isEmpty, let chatService else {
                    continuation.finish(throwing: LLMError.notConfigured)
                    return
                }
                
                await MainActor.run { 
                    isProcessing = true
                    streamingContent = ""
                    let userMsg = ChatMessage(role: .user, content: query)
                    self.chatHistory.append(userMsg)
                    historyStore.append(userMsg)
                }
                
                let context = contextBuilder.buildRelevantContext(query: query, pages: pages)
                let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
                let history = Array(historyStore.recent(10))
                
                do {
                    for try await chunk in chatService.streamChat(systemPrompt: systemPrompt, query: query, history: history) {
                        await MainActor.run { streamingContent += chunk }
                        continuation.yield(chunk)
                    }
                    
                    await MainActor.run {
                        let assistantMsg = ChatMessage(role: .assistant, content: streamingContent)
                        self.chatHistory.append(assistantMsg)
                        historyStore.append(assistantMsg)
                        historyStore.persistToDisk()
                        isProcessing = false
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run { isProcessing = false }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - LLMKnowledgeServiceProtocol

    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult {
        guard isEnabled, !apiKey.isEmpty else { throw LLMError.notConfigured }
        let prompt = contextBuilder.buildIngestPrompt(title: title, rawContent: rawContent, pages: pages)
        let response = try await generate(prompt: prompt, systemPrompt: "")
        
        if let result = LLMResponseProcessor.parseSmartIngest(response) {
            return result
        }
        throw LLMError.invalidResponse
    }

    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        guard let refactorService else { return [] }
        return try await refactorService.discoverPotentialLinks(content: content, existingTitles: existingTitles)
    }

    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        guard let refactorService else { return existingContent + "\n\n" + newContent }
        return try await refactorService.foldContent(existingContent: existingContent, newContent: newContent, title: title)
    }

    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion] {
        guard isEnabled, !apiKey.isEmpty else { return [] }
        let prompt = "Analyze these pages for refactoring (merging, splitting, or link improvement): " + pages.map { $0.title }.joined(separator: ", ")
        let response = try await generate(prompt: prompt, systemPrompt: "Return JSON array of RefactorSuggestion")
        return LLMResponseProcessor.parseRefactorSuggestions(response)
    }

    // MARK: - 连通性测试

    struct ValidationResult {
        let isSuccess: Bool
        let latencyMS: Int
        let errorCode: String?
        let errorMessage: String?
    }

    func validateAPIKey() async throws -> ValidationResult {
        let start = Date()
        do {
            _ = try await generate(prompt: "Hello", systemPrompt: "Keep it short.")
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ValidationResult(isSuccess: true, latencyMS: latency, errorCode: nil, errorMessage: nil)
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ValidationResult(isSuccess: false, latencyMS: latency, errorCode: "ERR", errorMessage: error.localizedDescription)
        }
    }

    // MARK: - LLMRetrievalServiceProtocol

    func rewriteQuery(_ query: String) async -> String {
        guard isEnabled, !apiKey.isEmpty else { return query }
        let prompt = contextBuilder.buildRewritePrompt(query: query)
        return (try? await generate(prompt: prompt, systemPrompt: "")) ?? query
    }

    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage] {
        guard isEnabled, !candidates.isEmpty else { return candidates }
        
        let titles = candidates.map { "\($0.title) (ID: \($0.id))" }.joined(separator: "\n")
        let prompt = PromptService.shared.rerankPrompt + "\n\nQuery: \(query)\n\nCandidates:\n\(titles)"
        
        let response = try await generate(prompt: prompt, systemPrompt: "")
        let rankedIDs = LLMResponseProcessor.parseJSONArray(response)
        
        // 根据返回的 ID 重新排序
        var result = candidates
        result.sort { a, b in
            let idxA = rankedIDs.firstIndex(of: a.id.uuidString) ?? 999
            let idxB = rankedIDs.firstIndex(of: b.id.uuidString) ?? 999
            return idxA < idxB
        }
        return result
    }

    // MARK: - 清理逻辑

    func clearChatHistory() {
        chatHistory.removeAll()
        historyStore.clear()
        objectWillChange.send()
    }
}
