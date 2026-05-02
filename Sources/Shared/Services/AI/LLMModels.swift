import Foundation

// MARK: - LLM Provider Metadata
@MainActor
struct LLMProviderMetadata: Codable {
    let id: String
    let nameKey: String
    let baseURL: String
    let defaultModel: String
    let suggestedModels: [String]
    let icon: String
}

// MARK: - LLM Registry
final class LLMRegistry {
    nonisolated(unsafe) static let shared = LLMRegistry()
    private var providers: [String: LLMProviderMetadata] = [:]
    
    private init() {
        loadProviders()
    }
    
    private func loadProviders() {
        // 首先尝试从 Bundle 加载（Apple 推荐方式）
        if let url = Bundle.main.url(forResource: "LLMProviders", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([LLMProviderMetadata].self, from: data) {
            for item in list {
                providers[item.id] = item
            }
            return
        }
        
        // 兜底方案：如果 JSON 未能加载（如尚未打包），使用硬编码数据
        let fallbacks: [LLMProviderMetadata] = [
            .init(id: "zhipu", nameKey: "llm.provider.zhipu", baseURL: "https://open.bigmodel.cn/api/paas/v4", defaultModel: "glm-4-flash", suggestedModels: ["glm-4-flash", "glm-4", "glm-4v"], icon: "sparkles"),
            .init(id: "minimax", nameKey: "llm.provider.minimax", baseURL: "https://api.minimax.chat/v1", defaultModel: "abab6.5-chat", suggestedModels: ["abab6.5-chat", "abab5.5-chat"], icon: "cpu"),
            .init(id: "qwen", nameKey: "llm.provider.qwen", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", defaultModel: "qwen-plus", suggestedModels: ["qwen-plus", "qwen-max", "qwen-turbo"], icon: "cloud.fill"),
            .init(id: "deepseek", nameKey: "llm.provider.deepSeek", baseURL: "https://api.deepseek.com/v1", defaultModel: "deepseek-v4-pro", suggestedModels: ["deepseek-v4-pro", "deepseek-v4-lite"], icon: "wave.3.forward"),
            .init(id: "kimi", nameKey: "llm.provider.kimi", baseURL: "https://api.moonshot.cn/v1", defaultModel: "moonshot-v1-8k", suggestedModels: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"], icon: "moon.fill"),
            .init(id: "siliconflow", nameKey: "llm.provider.siliconflow", baseURL: "https://api.siliconflow.cn/v1", defaultModel: "deepseek-ai/DeepSeek-V3", suggestedModels: ["deepseek-ai/DeepSeek-V3", "deepseek-ai/DeepSeek-V2.5", "Qwen/Qwen2.5-72B-Instruct"], icon: "bolt.fill"),
            .init(id: "custom", nameKey: "llm.provider.custom", baseURL: "", defaultModel: "", suggestedModels: ["default"], icon: "server.rack")
        ]
        for item in fallbacks {
            providers[item.id] = item
        }
    }
    
    func metadata(for id: String) -> LLMProviderMetadata? {
        providers[id]
    }
}

// MARK: - LLM Provider
enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case zhipu = "zhipu"
    case minimax = "minimax"
    case qwen = "qwen"
    case deepSeek = "deepseek"
    case kimi = "kimi"
    case siliconflow = "siliconflow"
    case custom = "custom"
    
    var id: String { rawValue }
    
    private var metadata: LLMProviderMetadata? {
        LLMRegistry.shared.metadata(for: rawValue)
    }
    
    var displayName: String {
        if let key = metadata?.nameKey {
            return Localized.tr(key)
        }
        return rawValue.capitalized
    }
    
    var defaultBaseURL: String {
        metadata?.baseURL ?? ""
    }
    
    var defaultModel: String {
        metadata?.defaultModel ?? ""
    }
    
    var suggestedModels: [String] {
        metadata?.suggestedModels ?? ["default"]
    }
    
    var icon: String {
        metadata?.icon ?? "server.rack"
    }
}

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var relatedPageIDs: [UUID]
    
    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        relatedPageIDs: [UUID] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.relatedPageIDs = relatedPageIDs
    }
}

// MARK: - Smart Ingest Result
struct SmartIngestResult: Codable {
    let compiledContent: String
    let suggestedTags: [String]
    let suggestedType: String
    let relatedTitles: [String]
    let summary: String
}

// MARK: - LLM Errors
enum LLMError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case apiError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return Localized.tr("llm.error.notConfigured")
        case .invalidURL:
            return Localized.tr("llm.error.invalidURL")
        case .invalidResponse:
            return Localized.tr("llm.error.invalidResponse")
        case .unauthorized:
            return Localized.tr("llm.error.unauthorized")
        case .rateLimited:
            return Localized.tr("llm.error.rateLimited")
        case .httpError(let code):
            return "\(Localized.tr("llm.error.httpError")): \(code)"
        case .apiError(let message):
            return "\(Localized.tr("llm.error.apiError")): \(message)"
        case .cancelled:
            return Localized.tr("llm.error.cancelled")
        }
    }
}

// MARK: - LLM Config (Persistence)
/// Manages LLM provider configuration with UserDefaults persistence.
final class LLMConfigStore: ObservableObject {
    @Published var provider: LLMProvider {
        didSet { saveConfig() }
    }
    @Published var apiKey: String {
        didSet { saveConfig() }
    }
    @Published var baseURL: String {
        didSet { saveConfig() }
    }
    @Published var model: String {
        didSet { saveConfig() }
    }
    @Published var isEnabled: Bool {
        didSet { saveConfig() }
    }
    @Published var autoScan: Bool {
        didSet { saveConfig() }
    }
    @Published var autoRefactor: Bool {
        didSet { saveConfig() }
    }
    
    private let configKey = "wikicraft_llm_config"
    
    struct Config: Codable {
        let provider: LLMProvider
        let apiKey: String
        let baseURL: String
        let model: String
        let isEnabled: Bool
        let autoScan: Bool
        let autoRefactor: Bool
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            self.provider = config.provider
            self.apiKey = config.apiKey
            self.baseURL = config.baseURL
            self.model = config.model
            self.isEnabled = config.isEnabled
            self.autoScan = config.autoScan
            self.autoRefactor = config.autoRefactor
        } else {
            self.provider = .deepSeek
            self.apiKey = ""
            self.baseURL = LLMProvider.deepSeek.defaultBaseURL
            self.model = LLMProvider.deepSeek.defaultModel
            self.isEnabled = false
            self.autoScan = true
            self.autoRefactor = false
        }
    }
    
    private func saveConfig() {
        let config = Config(
            provider: provider,
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            isEnabled: isEnabled,
            autoScan: autoScan,
            autoRefactor: autoRefactor
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}
