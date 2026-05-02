import Foundation
import Combine

// MARK: - LLM 服务 (轻量级编排器)
/// 组合了 LLMConfigStore (配置) + LLMContextBuilder (上下文) + ChatHistoryStore (历史) + LLMClient (客户端)。
/// 暴露与之前相同的公共接口，以确保视图层的零修改兼容性。
final class LLMService: ObservableObject, LLMServiceProtocol {
    
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
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var isProcessing = false
    
    // MARK: - 内部模块
    private var strategy: LLMStrategy?
    let configStore: LLMConfigStore
    private let historyStore: ChatHistoryStore
    private let contextBuilder = LLMContextBuilder()
    
    // MARK: - 专项解耦服务 (Architect 模式：单一职责)
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
        
        // 加载历史消息
        self.chatHistory = historyStore.messages
        
        // 初始化策略
        updateStrategy()
        
        // 设置外部配置同步
        setupExternalSync()
    }
    
    /// 同步配置存储层的变更到当前实例的 Published 属性
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
                self.updateStrategy()
            }
            .store(in: &cancellables)
    }
    
    private func updateStrategy() {
        switch provider {
        case .deepSeek, .siliconflow:
            strategy = DeepSeekStrategy(apiKey: apiKey, model: model, baseURL: baseURL)
        case .custom:
            strategy = DeepSeekStrategy(apiKey: apiKey, model: model, baseURL: baseURL)
        default:
            strategy = OllamaStrategy(model: model, baseURL: baseURL)
        }
        
        // 同步更新专项服务
        let client = makeClient()
        refactorService = LLMRefactorService(client: client, model: model)
        chatService = LLMChatService(client: client, model: model)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 配置常量
    /// 非流式对话温度
    private static let chatTemperature: Double = 0.7
    /// 非流式对话最大 Token
    private static let chatMaxTokens: Int = 2000
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
    /// Builds the messages array for chat completions, including system prompt + history + query.
    private func buildChatMessages(systemPrompt: String, query: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for msg in historyStore.recent(10) {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        messages.append(["role": "user", "content": query])
        return messages
    }
    
    /// Creates a non-streaming request body dictionary.
    private func makeChatRequestBody(systemPrompt: String, query: String) -> [String: Any] {
        [
            "model": model,
            "messages": buildChatMessages(systemPrompt: systemPrompt, query: query),
            "temperature": Self.chatTemperature,
            "max_tokens": Self.chatMaxTokens
        ]
    }
    
    /// Creates a streaming request body dictionary.
    private func makeStreamingRequestBody(systemPrompt: String, query: String) -> [String: Any] {
        [
            "model": model,
            "messages": buildChatMessages(systemPrompt: systemPrompt, query: query),
            "temperature": Self.chatTemperature,
            "max_tokens": Self.chatMaxTokens,
            "stream": true
        ]
    }
    
    // MARK: - Chat Completion (Non-streaming)
    func chat(query: String, pages: [WikiPage]) async throws -> ChatMessage {
        guard isEnabled, !apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let context = contextBuilder.buildRelevantContext(query: query, pages: pages)
        let systemPrompt = contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
        
        let requestBody = makeChatRequestBody(systemPrompt: systemPrompt, query: query)
        
        let response = try await makeClient().sendRequest(body: requestBody)
        
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        
        let linkedTitles = extractWikiLinks(from: content)
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
    func chatStream(query: String, pages: [WikiPage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { [self] in
                await MainActor.run { isProcessing = true }
                guard self.isEnabled, !self.apiKey.isEmpty else {
                    continuation.finish(throwing: LLMError.notConfigured)
                    await MainActor.run { isProcessing = false }
                    return
                }
                
                let context = self.contextBuilder.buildRelevantContext(query: query, pages: pages)
                let systemPrompt = self.contextBuilder.buildSystemPrompt(pages: pages) + "\n\n" + context
                
                let requestBody = self.makeStreamingRequestBody(systemPrompt: systemPrompt, query: query)
                
                do {
                let streamResult = self.makeClient().sendStreamingRequest(body: requestBody)
                    
                    var fullContent = ""
                    
                    for try await bytesOrEnd in streamResult {
                        for try await line in bytesOrEnd.lines {
                            if Task.isCancelled { break }
                            guard line.hasPrefix("data: ") else { continue }
                            let dataString = String(line.dropFirst(6))
                            if dataString == "[DONE]" { break }
                            
                            guard let data = dataString.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let choices = json["choices"] as? [[String: Any]],
                                  let delta = choices.first?["delta"] as? [String: Any],
                                  let content = delta["content"] as? String else {
                                continue
                            }
                            
                            fullContent += content
                            continuation.yield(content)
                        }
                    }
                    
                    let userMessage = ChatMessage(role: .user, content: query)
                    let linkedTitles = self.extractWikiLinks(from: fullContent)
                    let relatedIDs = pages.filter { linkedTitles.contains($0.title) }.map(\.id)
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: fullContent,
                        relatedPageIDs: relatedIDs
                    )
                    
                    self.chatHistory.append(userMessage)
                    self.chatHistory.append(assistantMessage)
                    
                    await MainActor.run { self.isProcessing = false }
                    continuation.finish()
                } catch {
                    await MainActor.run { self.isProcessing = false }
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Smart Ingest
    func smartIngest(title: String, rawContent: String, pages: [WikiPage]) async throws -> SmartIngestResult {
        guard isEnabled, !apiKey.isEmpty else {
            throw LLMError.notConfigured
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let prompt = contextBuilder.buildIngestPrompt(title: title, rawContent: rawContent, pages: pages)
        let systemPrompt = Localized.tr("llm.ingest.systemPrompt")
        
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
    
    // MARK: - Utility
    private func extractWikiLinks(from text: String) -> [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
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
        guard isEnabled else { return [] }
        
        let prompt = """
        \(PromptService.shared.potentialLinksPrompt)
        
        现有页面标题列表：
        \(existingTitles.joined(separator: ", "))
        
        待分析文本：
        \"\"\"
        \(content)
        \"\"\"
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.1,
            "max_tokens": 500
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return []
        }
        
        return parseJSONArray(text)
    }
    
    /// 增量折叠 (Smart Folding): 将新资料智能融合进现有页面
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        guard isEnabled else { return existingContent + "\n\n" + newContent }
        
        let prompt = """
        \(PromptService.shared.foldingPrompt)
        
        现有页面内容：
        \(existingContent)
        
        新资料内容：
        \(newContent)
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 2000
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return existingContent + "\n\n" + newContent
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 分析一组页面以获取重构建议（合并、拆分、重命名）
    func analyzeForRefactoring(pages: [WikiPage]) async throws -> [RefactorSuggestion] {
        guard isEnabled else { return [] }
        
        let pageData = pages.map { "\($0.title): \($0.content.prefix(150))..." }.joined(separator: "\n---\n")
        
        let prompt = """
        \(PromptService.shared.refactorPrompt)
        
        页面简述列表：
        \(pageData)
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return []
        }
        
        return parseRefactorSuggestions(text)
    }
    
    /// 通用生成接口 (委托给 Strategy)
    func generate(prompt: String, temperature: Double = 0.7) async throws -> String {
        guard isEnabled, let strategy = strategy else {
            throw URLError(.cancelled)
        }
        return try await strategy.generate(prompt: prompt, temperature: temperature)
    }
    
    /// 查询改写 (Query Rewrite)
    func rewriteQuery(_ query: String) async -> String {
        guard isEnabled, let strategy = strategy else { return query }
        return await strategy.rewrite(query: query)
    }
    
    /// 智能重排 (AI Re-rank)
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage] {
        guard isEnabled, !candidates.isEmpty, let strategy = strategy else { return candidates }
        return try await strategy.rerank(query: query, candidates: candidates)
    }
    
    /// 抽取任务项
    func extractActions(content: String) async throws -> String {
        let prompt = """
        # Role: 资深项目经理
        
        # Task: 
        从以下内容中提取所有明确的、可执行的“行动项 (Action Items)”。
        
        # Requirements:
        1. 使用 Markdown Checkbox 格式 (- [ ])。
        2. 识别负责人（如果提及）和截止日期。
        3. 如果有优先级，请标注 [High/Medium/Low]。
        4. 仅返回 Markdown 任务列表，不要有额外废话。
        
        # Content:
        ---
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.3)
    }
    
    /// 语义总结
    func summarize(content: String) async throws -> String {
        let prompt = """
        请为以下内容生成一个简洁的“语义摘要”。
        要求：
        1. 字数控制在 200 字以内。
        2. 突出核心观点和结论。
        3. 采用专业、理性的语气。
        
        内容：
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.3)
    }

    // MARK: - Synthesis Lab (NotebookLM Style)
    
    /// 生成思维导图 (Mermaid 格式)
    func generateMindMap(content: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.mindmapPrompt)
        # Content:
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.2)
    }
    
    /// 生成知识测验
    func generateQuiz(content: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.quizPrompt)
        # Content:
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.3)
    }
    
    /// 生成演示文稿大纲 (Markdown Slides)
    func generatePresentation(content: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.slidesPrompt)
        # Content:
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.4)
    }
    
    /// 生成深度报告
    func generateReport(content: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.reportPrompt)
        # Content:
        \(content)
        """
        return try await generate(prompt: prompt, temperature: 0.3)
    }
    
    /// 针对具体的 Lint 问题提供 AI 修复建议
    func suggestFix(issue: LintIssue, pages: [WikiPage]) async throws -> String {
        guard isEnabled else { return "请先配置并启用大模型以获取修复建议。" }

        let pageTitle = pages.first(where: { $0.id == issue.pageID })?.title ?? "未知页面"
        let pageContent = pages.first(where: { $0.title == pageTitle })?.content ?? ""
        let otherTitles = pages.map { $0.title }.filter { $0 != pageTitle }
        
        let prompt = """
        \(PromptService.shared.fixSuggestionPrompt)
        
        页面标题：\(pageTitle)
        问题描述：\(issue.message)
        问题类型：\(issue.type.icon)
        
        当前页面部分内容：
        \"\"\"
        \(pageContent.prefix(500))
        \"\"\"
        
        知识库中的其他页面标题：
        \(otherTitles.prefix(50).joined(separator: ", "))
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.3,
            "max_tokens": 500
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return "无法获取建议。"
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 辅助解析器
    
    private func parseJSONArray(_ text: String) -> [String] {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }
    
    private func parseRefactorSuggestions(_ text: String) -> [RefactorSuggestion] {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([RefactorSuggestion].self, from: data) else {
            return []
        }
        return array
    }
    
    /// 自动生成启发式问题：分析知识库并推荐 3 个最值得深挖的问题
    func generateInsightfulQuestions(pages: [WikiPage]) async throws -> [String] {
        guard isEnabled, !pages.isEmpty else { return [] }
        
        let pageSummaries = pages.sorted(by: { $0.updated > $1.updated })
            .prefix(15)
            .map { "\($0.title): \($0.content.prefix(100))..." }
            .joined(separator: "\n")
        
        let prompt = """
        \(PromptService.shared.quizPrompt)
        
        要求：
        1. 仅返回 JSON 数组格式，例如: ["问题1", "问题2", "问题3"]
        
        知识库概览：
        \(pageSummaries)
        """
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.4,
            "max_tokens": 500
        ]
        
        let response = try await makeClient().sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            return []
        }
        
        return parseJSONArray(text)
    }
}

// MARK: - 辅助模型
struct RefactorSuggestion: Codable, Identifiable {
    var id: String { target + type }
    let type: String // merge, split, rename
    let target: String
    let reason: String
    let suggestion: String
}
