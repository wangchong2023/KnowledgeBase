import Foundation

// MARK: - DeepSeek Strategy (Cloud)
final class DeepSeekStrategy: LLMStrategy {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    
    init(apiKey: String, model: String = "deepseek-chat", baseURL: String = AppConfig.deepseekDefaultURL) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
    }
    
    func generate(prompt: String, temperature: Double) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": temperature
        ]
        let response = try await makeRequest(body: requestBody)
        return try parseResponse(response)
    }
    
    func rewrite(query: String) async -> String {
        // 搜索页面基于本地搜索，不再进行大模型改写
        return query
    }
    
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage] {
        // 搜索页面基于本地搜索，不再进行大模型重排
        return candidates
    }
    
    private func makeRequest(body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    private func parseResponse(_ response: [String: Any]) throws -> String {
        if let choices = response["choices"] as? [[String: Any]],
           let first = choices.first,
           let msg = first["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw URLError(.badServerResponse)
    }
}

// MARK: - Ollama Strategy (Local)
final class OllamaStrategy: LLMStrategy {
    private let baseURL: String
    private let model: String
    
    init(model: String = "llama3", baseURL: String = AppConfig.ollamaDefaultURL) {
        self.model = model
        self.baseURL = baseURL
    }
    
    func generate(prompt: String, temperature: Double) async throws -> String {
        let url = URL(string: "\(baseURL)/api/generate")!
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": temperature]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return response?["response"] as? String ?? ""
    }
    
    func rewrite(query: String) async -> String {
        return query
    }
    
    func rerank(query: String, candidates: [WikiPage]) async throws -> [WikiPage] {
        return candidates
    }
}
