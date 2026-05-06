// Chat视图模型.swift
//
// 作者: Wang Chong
// 功能说明: Chat视图模型.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var inputText = ""
    var insightfulQuestions: [String] = []

    @ObservationIgnored @Inject private var aiSynthesis: AISynthesisService

    func loadInsightfulQuestions(pages: [WikiPage]) async {
        do {
            insightfulQuestions = try await aiSynthesis.generateInsightfulQuestions(pages: pages)
        } catch {
            insightfulQuestions = []
        }
    }

    func exportChat(history: [ChatMessage]) async throws -> URL {
        let md: String = history.map { msg in
            let role = msg.role == .user ? "You" : "AI"
            return "## \(role)\n\n\(msg.content)"
        }.joined(separator: "\n\n---\n\n")

        return try await WebViewExportService.shared.exportToPDF(markdown: md, fileName: "Chat_Export")
    }
}
