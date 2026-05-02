import Foundation

// MARK: - LLM HTTP Client
/// Handles all HTTP communication with OpenAI-compatible LLM APIs.
/// Supports both non-streaming and streaming (SSE) requests.
final class LLMClient {
    
    // MARK: - Config
    private let baseURL: String
    private let apiKey: String
    private var currentTask: URLSessionDataTask?
    
    // MARK: - Constants
    /// Timeout for non-streaming requests (seconds)
    private static let defaultTimeout: TimeInterval = 60
    /// Timeout for streaming requests (seconds, longer to accommodate slow responses)
    private static let streamingTimeout: TimeInterval = 120
    
    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - URL Normalization
    private var normalizedBaseURL: String {
        baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }
    
    // MARK: - Non-streaming Request
    /// Sends a chat completion request and returns the parsed JSON response.
    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(normalizedBaseURL)/chat/completions") else {
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.defaultTimeout
        
        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 { throw APIError(statusCode: 401, message: "Unauthorized: Invalid API Key") }
        if httpResponse.statusCode == 429 { throw APIError(statusCode: 429, message: "Rate Limited: Too many requests") }
        
        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError(statusCode: httpResponse.statusCode, message: message)
            }
            throw APIError(statusCode: httpResponse.statusCode, message: "HTTP Error \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        return json
    }
    
    // MARK: - Streaming Request (SSE)
    /// Sends a streaming chat completion request and returns an async stream of text chunks.
    func sendStreamingRequest(body: [String: Any]) -> AsyncThrowingStream<URLSession.AsyncBytes, Error> {
        // Capture necessary properties directly so they survive if LLMClient is deallocated
        let urlString = "\(self.normalizedBaseURL)/chat/completions"
        let token = self.apiKey
        
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: LLMError.invalidURL)
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = Self.streamingTimeout
                
                let httpBody = try? JSONSerialization.data(withJSONObject: body)
                request.httpBody = httpBody
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1))
                        return
                    }
                    
                    continuation.yield(bytes)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Cancel
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Error Types
    struct APIError: Error {
        let statusCode: Int
        let message: String
    }
}

// MARK: - SSE Stream Parser
/// Parses Server-Sent Events from a streaming response.
final class SSEParser {
    
    /// Parse SSE bytes into a sequence of content strings.
    static func parse(bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var fullContent = ""
                
                do {
                    for try await line in bytes.lines {
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
                    
                    // Yield accumulated full content at end
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
