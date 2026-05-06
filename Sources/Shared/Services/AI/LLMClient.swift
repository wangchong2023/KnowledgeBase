// LLMClient.swift
//
// 作者: Wang Chong
// 功能说明: 负责与兼容 OpenAI 协议的 LLM API 进行所有 HTTP 通信，支持非流式和流式 (SSE) 请求。
// 版本: 1.1
// 修改记录:
//   - 创建: 2026-05-02
//   - 2026-05-05: 升级文档规范，优化流式解析稳定性
// 日期: 2026-05-05
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

// MARK: - LLM 网络客户端
/// 负责与兼容 OpenAI 协议的 LLM API 进行所有 HTTP 通信。
/// 支持普通请求与流式 (SSE) 响应。
final class LLMClient: @unchecked Sendable {
    
    // MARK: - 配置
    private let baseURL: String
    private let apiKey: String
    private var currentTask: URLSessionDataTask?
    
    // MARK: - 常量
    /// 普通请求超时时间（秒）
    private static let defaultTimeout: TimeInterval = 60
    /// 流式请求超时时间（秒，考虑到首字响应可能较慢）
    private static let streamingTimeout: TimeInterval = 120
    
    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - 地址规范化
    private var normalizedBaseURL: String {
        baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }
    
    // MARK: - 普通请求
    /// 发送对话补全请求并返回解析后的 JSON 响应
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
        
        if httpResponse.statusCode == 401 { throw APIError(statusCode: 401, message: "鉴权失败：无效的 API Key") }
        if httpResponse.statusCode == 429 { throw APIError(statusCode: 429, message: "请求过快：触发速率限制") }
        
        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIError(statusCode: httpResponse.statusCode, message: message)
            }
            throw APIError(statusCode: httpResponse.statusCode, message: "HTTP 错误：状态码 \(httpResponse.statusCode)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        return json
    }
    
    // MARK: - 流式请求
    /// 发送流式对话补全请求并返回原始 AsyncBytes 流
    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        let urlString = "\(self.normalizedBaseURL)/chat/completions"
        let token = self.apiKey
        
        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Self.streamingTimeout
        
        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        return bytes
    }
    
    // MARK: - 取消任务
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - 错误类型定义
    struct APIError: Error, LocalizedError {
        let statusCode: Int
        let message: String
        
        var errorDescription: String? {
            return "\(message) (状态码: \(statusCode))"
        }
    }
}

// MARK: - SSE 流解析器
/// 负责从流式响应中解析服务器发送事件 (SSE)。
final class SSEParser {
    
    /// 将 SSE 字节流解析为内容字符串序列
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
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
