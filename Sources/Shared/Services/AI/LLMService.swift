// LLMService.swift
//
// 作者: Wang Chong
// 功能说明: 组合了 LLMConfigStore (配置) + LLMContextBuilder (上下文) + ChatHistoryStore (历史) + LLMClient (客户端)。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine

// MARK: - LLM 服务 (轻量级编排器)
/// 组合了 LLMConfigStore (配置) + LLMContextBuilder (上下文) + ChatHistoryStore (历史) + LLMClient (客户端)。
/// 暴露与之前相同的公共接口，以确保视图层的零修改兼容性。
@MainActor
final class LLMService: ObservableObject, LLMServiceProtocol, @unchecked Sendable {
    
    // MARK: - UI 状态属性 (向后兼容)
    @Published var provider: LLMProvider {
        didSet {
            configStore.provider = provider
        }
    }
    @Published var apiKey: String {
        didSet {
            configStore.apiKey = apiKey
        }
    }
    @Published var baseURL: String {
        didSet {
            configStore.baseURL = baseURL
        }
    }
    @Published var model: String {
        didSet {
            configStore.model = model
        }
    }
    @Published var isEnabled: Bool {
        didSet {
            configStore.isEnabled = isEnabled
        }
    }
    @Published var autoScan: Bool {
        didSet {
            configStore.autoScan = autoScan
        }
    }
    @Published var autoRefactor: Bool {
        didSet {
            configStore.autoRefactor = autoRefactor
        }
    }
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var isProcessing = false
    
    // MARK: - 内部模块
    let configStore: LLMConfigStore
    private let historyStore: ChatHistoryStore
    private let contextBuilder = LLMContextBuilder()
    
    // MARK: - 专项解耦服务 (Architect 模式：单一职责)
    @Published var activeAdapter: LLMAdapter?
    private var refactorService: LLMRefactorService?
    private var chatService: LLMChatService?
    
    // MARK: - 聊天历史
    @Published var chatHistory: [ChatMessage] = []
    
    // MARK: - 初始化
    init() {
        self.configStore = LLMConfigStore()
        self.historyStore = ChatHistoryStore()
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
        
        // 初始化策略
        updateAdapter()
        
        // 设置外部配置同步
        setupExternalSync()
    }
    
    /// 同步配置存储层的变更到当前实例 of Published 属性
    private func setupExternalSync() {
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
                self.updateAdapter()
            }
            .store(in: &cancellables)
    }
    
    private func updateAdapter() {
        switch provider {
        case .deepSeek, .siliconflow, .custom:
            activeAdapter = OpenAICompatibleAdapter(id: provider.rawValue, displayName: provider.rawValue.capitalized, config: configStore)
        default:
            activeAdapter = OllamaAdapter(model: model, baseURL: baseURL)
        }
        
        // 同步更新专项服务
        let client = makeClient()
        refactorService = LLMRefactorService(client: client, model: model)
        chatService = LLMChatService(client: client, model: model)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 配置常量
    /// 智能编译温度 (较低值 = 更专注/确定)
    private static let ingestTemperature: Double = 0.3
    /// 智能编译最大 Token
    private static let ingestMaxTokens: Int = 3000
    /// 验证连接时的最大 Token (极小响应即可)
    private static let validationMaxTokens: Int = 5

    // MARK: - 客户端工厂
    private func makeClient() -> LLMClient {
        LLMClient(baseURL: baseURL, apiKey: apiKey)
    }
    
    // MARK: - 请求体构造
    // MARK: - Chat Completion (Non-streaming)
    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage {
        guard isEnabled, !apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let context = contextBuilder.buildRelevantContext(query: query, pages: pages)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
        
        guard let chatService else { throw LLMError.notConfigured }
        let history = Array(historyStore.recent(10))
        let content = try await chatService.chat(systemPrompt: systemPrompt, query: query, history: history)

        let linkedTitles = chatService.extractWikiLinks(from: content)
        let relatedIDs = pages.filter { linkedTitles.contains($0.title) }.map(\.id)
        
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: content,
            relatedPageIDs: relatedIDs
        )
        
        chatHistory.append(ChatMessage(role: .user, content: query))
        chatHistory.append(assistantMessage)
        
        return assistantMessage
    }
    
    // MARK: - Streaming Chat
    
    /// 执行完整对话流程（由 ChatView 调用）
    func sendChatMessage(query: String, pages: [WikiPage]) async throws {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 1. 记录用户消息
        let userMessage = ChatMessage(role: .user, content: text)
        await MainActor.run {
            self.chatHistory.append(userMessage)
            self.historyStore.append(userMessage)
            self.streamingContent = ""
            self.isStreaming = true
        }
        
        // 2. 处理流式输出
        do {
            let stream = chatStream(query: text, pages: pages)
            var hasReceivedFirstChunk = false
            
            for try await chunk in stream {
                if !hasReceivedFirstChunk {
                    hasReceivedFirstChunk = true
                    HapticManager.shared.trigger(.link)
                }
                await MainActor.run {
                    self.streamingContent += chunk
                }
            }
            
            await MainActor.run {
                self.streamingContent = ""
                self.isStreaming = false
            }
        } catch {
            await MainActor.run {
                self.isStreaming = false
                // 出错时尝试保存已生成的片段
                let partial = self.streamingContent
                if !partial.isEmpty {
                    let linkedTitles = chatService?.extractWikiLinks(from: partial) ?? []
                    let relatedIDs = pages.filter { linkedTitles.contains($0.title) }.map(\.id)
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: partial,
                        relatedPageIDs: relatedIDs
                    )
                    self.chatHistory.append(assistantMessage)
                    self.historyStore.append(assistantMessage)
                }
                self.streamingContent = ""
            }
            throw error
        }
    }

    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream(String.self) { continuation in
            Task { [self] in
                await MainActor.run { isProcessing = true }
                guard self.isEnabled, !self.apiKey.isEmpty else {
                    continuation.finish(throwing: LLMError.notConfigured)
                    await MainActor.run { isProcessing = false }
                    return
                }
                
                let context = self.contextBuilder.buildRelevantContext(query: query, pages: pages)
                let systemPrompt = self.contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
                
                guard let chatService else {
                    continuation.finish(throwing: LLMError.notConfigured)
                    await MainActor.run { self.isProcessing = false }
                    return
                }
                let history = Array(self.historyStore.recent(10))

                do {
                    var fullContent = ""
                    for try await chunk in chatService.streamChat(systemPrompt: systemPrompt, query: query, history: history) {
                        if Task.isCancelled { break }
                        fullContent += chunk
                        continuation.yield(chunk)
                    }

                    let linkedTitles = chatService.extractWikiLinks(from: fullContent)
                    let relatedIDs = pages.filter { linkedTitles.contains($0.title) }.map(\.id)
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: fullContent,
                        relatedPageIDs: relatedIDs
                    )
                    
                    await MainActor.run {
                        self.chatHistory.append(assistantMessage)
                        self.isProcessing = false
                        self.historyStore.append(assistantMessage)
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run { self.isProcessing = false }
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Adapter Pattern (Expert Optimization)
    
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        let fullSystemPrompt = systemPrompt + (systemPrompt.isEmpty ? "" : PromptService.shared.languageInstruction)
        if let adapter = activeAdapter {
            let capturedAdapter = adapter
            return try await capturedAdapter.generate(prompt: prompt, systemPrompt: fullSystemPrompt)
        }
        
        // Fallback to legacy implementation if no adapter is set
        guard isEnabled, !apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": fullSystemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        
        return content
    }
    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult {
        guard isEnabled, !apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        TaskCenter.shared.updateLatestStatus("🔍 \(Localized.tr("ai.status.preprocessing")): \(title)")
        let prompt = contextBuilder.buildIngestPrompt(title: title, rawContent: rawContent, pages: pages)
        let systemPrompt = Localized.tr("llm.ingest.systemPrompt")
        
        TaskCenter.shared.updateLatestStatus("🧠 \(Localized.tr("ai.status.analyzing")): \(title)")
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": Self.ingestTemperature,
            "max_tokens": Self.ingestMaxTokens
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        
        let jsonStr = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonStr.data(using: .utf8),
              let result = try? JSONDecoder().decode(SmartIngestResult.self, from: data) else {
            return SmartIngestResult(
                compiledContent: content,
                suggestedTags: [],
                suggestedType: "concept",
                relatedTitles: [],
                summary: String(content.prefix(100))
            )
        }
        
        return result
    }
    
    func clearChatHistory() {
        chatHistory.removeAll()
        historyStore.clear()
    }
    
    func saveChatHistoryPublic() {
        historyStore.persistToDisk()
    }
    
    func cancelCurrentRequest() {
        isStreaming = false
        streamingContent = ""
    }
    
    struct ValidationResult {
        let isSuccess: Bool
        let latencyMS: Int
        let errorCode: String?
        let errorMessage: String?
    }
    
    func validateAPIKey() async throws -> ValidationResult {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        guard !baseURL.isEmpty else { throw LLMError.invalidURL }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": Self.validationMaxTokens
        ]
        
        let startTime = Date()
        do {
            _ = try await makeClient().sendRequest(body: requestBody)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return ValidationResult(isSuccess: true, latencyMS: latency, errorCode: nil, errorMessage: nil)
        } catch let error as LLMClient.APIError {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return ValidationResult(isSuccess: false, latencyMS: latency, errorCode: "\(error.statusCode)", errorMessage: error.message)
        } catch {
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            return ValidationResult(isSuccess: false, latencyMS: latency, errorCode: "Unknown", errorMessage: error.localizedDescription)
        }
    }
    
    // MARK: - 知识库维护 (Karpathy 模式)
    
    /// 扫描文本以发现潜在的内部链接建议
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        guard isEnabled, let refactorService else { return [] }
        return try await refactorService.discoverPotentialLinks(content: content, existingTitles: existingTitles)
    }

    /// 增量折叠 (Smart Folding): 将新资料智能融合进现有页面
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        guard isEnabled, let refactorService else { return existingContent + "\n\n" + newContent }
        return try await refactorService.foldContent(existingContent: existingContent, newContent: newContent, title: title)
    }

    /// 分析一组页面以获取重构建议（合并、拆分、重命名）
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion] {
        guard isEnabled, let refactorService else { return [] }
        return try await refactorService.analyzeForRefactoring(pages: pages)
    }

    /// 查询改写 (Query Rewrite)
    func rewriteQuery(_ query: String) async -> String {
        guard isEnabled, let adapter = activeAdapter else { return query }
        return (try? await adapter.generate(prompt: "Query: \(query)", systemPrompt: Localized.tr("prompt.queryRewrite.instruction"))) ?? query
    }

    /// 智能重排 (AI Re-rank)
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage] {
        guard isEnabled, !candidates.isEmpty, let _ = activeAdapter else { return candidates }
        return candidates
    }
}
