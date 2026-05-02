import Foundation

/// LLM 对话服务 (Architect & Dev 视角：解耦对话逻辑)
final class LLMChatService {
    private let client: LLMClient
    private let model: String
    
    init(client: LLMClient, model: String) {
        self.client = client
        self.model = model
    }
    
    func makeChatRequestBody(systemPrompt: String, query: String, history: [[String: Any]], temperature: Double, maxTokens: Int) -> [String: Any] {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        messages.append(contentsOf: history)
        messages.append(["role": "user", "content": query])
        
        return [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
    }
    
    func chat(requestBody: [String: Any]) async throws -> String {
        let response = try await client.sendRequest(body: requestBody)
        guard let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "LLMChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        return content
    }
}
