import Foundation

// MARK: - LLM Provider
enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case deepSeek = "deepseek"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openAI: return L.tr("llm.provider.openAI")
        case .deepSeek: return L.tr("llm.provider.deepSeek")
        case .custom: return L.tr("llm.provider.custom")
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .deepSeek: return "https://api.deepseek.com/v1"
        case .custom: return ""
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .deepSeek: return "deepseek-chat"
        case .custom: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .openAI: return "brain.head.profile.fill"
        case .deepSeek: return "wave.3.forward"
        case .custom: return "server.rack"
        }
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
            return L.tr("llm.error.notConfigured")
        case .invalidURL:
            return L.tr("llm.error.invalidURL")
        case .invalidResponse:
            return L.tr("llm.error.invalidResponse")
        case .unauthorized:
            return L.tr("llm.error.unauthorized")
        case .rateLimited:
            return L.tr("llm.error.rateLimited")
        case .httpError(let code):
            return "\(L.tr("llm.error.httpError")): \(code)"
        case .apiError(let message):
            return "\(L.tr("llm.error.apiError")): \(message)"
        case .cancelled:
            return L.tr("llm.error.cancelled")
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
    
    private let configKey = "wikicraft_llm_config"
    
    struct Config: Codable {
        let provider: LLMProvider
        let apiKey: String
        let baseURL: String
        let model: String
        let isEnabled: Bool
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            self.provider = config.provider
            self.apiKey = config.apiKey
            self.baseURL = config.baseURL
            self.model = config.model
            self.isEnabled = config.isEnabled
        } else {
            self.provider = .openAI
            self.apiKey = ""
            self.baseURL = LLMProvider.openAI.defaultBaseURL
            self.model = LLMProvider.openAI.defaultModel
            self.isEnabled = false
        }
    }
    
    private func saveConfig() {
        let config = Config(
            provider: provider,
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            isEnabled: isEnabled
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}
