import Foundation
import Combine

// MARK: - LLM Service (Refactored — Thin Orchestrator)
/// Composes LLMConfigStore + LLMContextBuilder + ChatHistoryStore + LLMClient.
/// Exposes the same public interface as before for zero-view-change compatibility.
final class LLMService: ObservableObject {
    
    // MARK: - Published UI State (backward compatible — views read these)
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
    
    // MARK: - Sub-modules
    let configStore: LLMConfigStore
    private let historyStore: ChatHistoryStore
    private let contextBuilder = LLMContextBuilder()
    
    // MARK: - Chat History (backward compatible — views read/write this directly)
    @Published var chatHistory: [ChatMessage] = []
    
    // MARK: - Init
    init() {
        self.configStore = LLMConfigStore()
        self.historyStore = ChatHistoryStore()
        // Initialize published properties from config store
        self._provider = .init(initialValue: configStore.provider)
        self._apiKey = .init(initialValue: configStore.apiKey)
        self._baseURL = .init(initialValue: configStore.baseURL)
        self._model = .init(initialValue: configStore.model)
        self._isEnabled = .init(initialValue: configStore.isEnabled)
        
        // Load chat history from persistent store
        self.chatHistory = historyStore.messages
        
        // Listen for external config changes (e.g., from SettingsView direct writes)
        setupExternalSync()
    }
    
    /// Syncs changes from configStore back into our @Published properties.
    private func setupExternalSync() {
        // Use configStore.objectWillChange to avoid needing Combine's publisher(for:) extension.
        // Each sink updates the specific published property when the configStore changes.
        configStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.configStore.provider != self.provider { self.provider = self.configStore.provider }
                if self.configStore.apiKey != self.apiKey { self.apiKey = self.configStore.apiKey }
                if self.configStore.baseURL != self.baseURL { self.baseURL = self.configStore.baseURL }
                if self.configStore.model != self.model { self.model = self.configStore.model }
                if self.configStore.isEnabled != self.isEnabled { self.isEnabled = self.configStore.isEnabled }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    /// Non-streaming chat temperature
    private static let chatTemperature: Double = 0.7
    /// Non-streaming chat max tokens
    private static let chatMaxTokens: Int = 2000
    /// Smart ingest temperature (lower = more focused/deterministic)
    private static let ingestTemperature: Double = 0.3
    /// Smart ingest max tokens
    private static let ingestMaxTokens: Int = 3000
    /// Validation request max tokens (minimal response)
    private static let validationMaxTokens: Int = 5

    // MARK: - Client Factory (stateless per-request)
    private func makeClient() -> LLMClient {
        LLMClient(baseURL: baseURL, apiKey: apiKey)
    }
    
    // MARK: - Request Body Builder
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
                guard self.isEnabled, !self.apiKey.isEmpty else {
                    continuation.finish(throwing: LLMError.notConfigured)
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
                        break
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
                    
                    continuation.finish()
                } catch {
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
        
        let prompt = contextBuilder.buildIngestPrompt(title: title, rawContent: rawContent, pages: pages)
        let systemPrompt = L.tr("llm.ingest.systemPrompt")
        
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
    
    func validateAPIKey() async throws -> Bool {
        guard !apiKey.isEmpty, !baseURL.isEmpty else { return false }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": Self.validationMaxTokens
        ]
        
        _ = try await makeClient().sendRequest(body: requestBody)
        return true
    }
}
