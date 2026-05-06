// LLMAdapters.swift
//
// 作者: Wang Chong
// 功能说明: OpenAI 兼容适配器 (DeepSeek, SiliconFlow 等)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// OpenAI 兼容适配器 (DeepSeek, SiliconFlow 等)
struct OpenAICompatibleAdapter: LLMAdapter {
    let id: String
    let displayName: String
    let config: LLMConfigStore
    
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        let client = LLMClient(baseURL: config.baseURL, apiKey: config.apiKey)
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        let response = try await client.sendRequest(body: body)
        guard let choices = response["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }
    
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        let client = LLMClient(baseURL: config.baseURL, apiKey: config.apiKey)
        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "stream": true
        ]
        
        struct SendableBody: @unchecked Sendable {
            let dict: [String: Any]
        }
        let safeBody = SendableBody(dict: body)
        let capturedClient = client
        
        return AsyncThrowingStream { @Sendable continuation in
            Task {
                do {
                    let bytes = try await capturedClient.sendStreamingRequest(body: safeBody.dict)
                    for try await chunk in SSEParser.parse(bytes: bytes) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Ollama 本地适配器
struct OllamaAdapter: LLMAdapter {
    let id: String = "ollama"
    let displayName: String = "Ollama (Local)"
    let model: String
    let baseURL: String
    
    func generate(prompt: String, systemPrompt: String) async throws -> String {
        // 实现略，调用 Ollama API
        return "Ollama Result"
    }
    
    func chatStream(messages: [[String: Any]]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { _ in }
    }
}

extension OpenAICompatibleAdapter: @unchecked Sendable {}
