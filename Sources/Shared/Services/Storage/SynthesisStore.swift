// SynthesisStore.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识合成数据管理仓储（SynthesisStore），负责管理通过 AI 生成的各类高级知识产出（文档、测验、图表）。
// 核心职责：
// 1. 持久化存储：将合成文档通过 UserDefaults 进行分类本地化存储，支持不同类型的并发管理。
// 2. 任务状态机：维护各类合成任务的生命周期状态（空闲、生成中、已完成、错误）。
// 3. 数据生命周期：提供文档的重命名、单项删除、批量清理及导出 PDF/PPTX 的能力。
// 4. 驱动 UI：通过 Swift 6 Observation 机制实时驱动 SynthesisView 的视图更新。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 增加详细中文文档注释，规范函数头
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation
import Combine

@MainActor
@Observable
final class SynthesisStore {
    struct SynthesisDocument: Codable, Identifiable, Sendable {
        let id: UUID
        let type: SynthesisType
        let name: String
        let content: String
        let createdAt: Date
        let size: Int // 内容字节大小
    }

    enum SynthesisType: String, CaseIterable, Codable, Identifiable, Sendable {
        case mindmap = "mindmap"
        case slides = "slides"
        case quiz = "quiz"
        case report = "report"
        case infographic = "infographic"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mindmap: return Localized.tr("prompt.expert.mindmap.title")
            case .slides: return Localized.tr("prompt.expert.slides.title")
            case .quiz: return Localized.tr("prompt.expert.quiz.title")
            case .report: return Localized.tr("prompt.expert.report.title")
            case .infographic: return Localized.tr("page.ai.infographic")
            }
        }
        var icon: String {
            switch self {
            case .mindmap: return "circle.hexagongrid.fill"
            case .slides: return "play.rectangle"
            case .quiz: return "checklist.checked"
            case .report: return "doc.text.magnifyingglass"
            case .infographic: return "chart.bar.doc.horizontal"
            }
        }
        var formatIcon: String {
            switch self {
            case .mindmap: return "doc.plaintext"
            case .slides: return "play.rectangle.fill"
            case .quiz: return "checklist.checked"
            case .report: return "doc.richtext.fill"
            case .infographic: return "chart.bar.fill"
            }
        }
        var formatColor: Color {
            switch self {
            case .mindmap: return .blue
            case .slides: return .orange
            case .quiz: return .green
            case .report: return .red
            case .infographic: return .purple
            }
        }
    }

    enum SynthesisStatus: Equatable, Sendable {
        case idle
        case generating
        case completed
        case error(String)
        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    @ObservationIgnored private var _synthesisResults: [SynthesisType: [SynthesisDocument]] = [:]
    var synthesisResults: [SynthesisType: [SynthesisDocument]] {
        get { access(keyPath: \.synthesisResults); return _synthesisResults }
        set { withMutation(keyPath: \.synthesisResults) { _synthesisResults = newValue } }
    }

    @ObservationIgnored private var _synthesisStates: [SynthesisType: SynthesisStatus] = {
        var states: [SynthesisType: SynthesisStatus] = [:]
        for type in SynthesisType.allCases { states[type] = .idle }
        return states
    }()
    
    var synthesisStates: [SynthesisType: SynthesisStatus] {
        get { access(keyPath: \.synthesisStates); return _synthesisStates }
        set { withMutation(keyPath: \.synthesisStates) { _synthesisStates = newValue } }
    }

    let maxSynthesisDocsPerType = 5

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        loadSynthesisResults()
        
        WikiEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.clearAll()
                }
            }
            .store(in: &cancellables)
    }

    /**
     * @description: 从持久化存储 (UserDefaults) 中加载所有已合成的历史文档
     * @return {*}
     */
    func loadSynthesisResults() {
        for type in SynthesisType.allCases {
            let key = "synthesis_docs_\(type.rawValue)"
            if let data = UserDefaults.standard.data(forKey: key),
               let docs = try? JSONDecoder().decode([SynthesisDocument].self, from: data) {
                _synthesisResults[type] = docs
                // 注意：这里不要覆盖状态，除非确实需要
                // _synthesisStates[type] = .completed
            }
        }
    }

    /**
     * @description: 保存单次合成结果，自动提取标题并净化文本语法
     * @param {SynthesisType} type 合成类型
     * @param {String} content 原始文本内容
     * @return {*}
     */
    func saveSynthesisResult(type: SynthesisType, content: String) {
        // 在保存前清理 LLM 可能产生的冗余转义字符
        let cleanedContent = Self.cleanMarkdown(content)
        let title = extractTitle(from: cleanedContent, type: type)
        let name = "\(title) - \(formatDateFull(Date()))"
        let size = cleanedContent.utf8.count
        let doc = SynthesisDocument(id: UUID(), type: type, name: name, content: cleanedContent, createdAt: Date(), size: size)

        var existing = synthesisResults[type] ?? []
        existing.insert(doc, at: 0)
        synthesisResults[type] = existing
        synthesisStates[type] = .completed
        persistResults(for: type)
    }

    /**
     * @description: 为已合成的文档重命名
     * @param {SynthesisType} type 合成类型
     * @param {UUID} docID 文档 ID
     * @param {String} newName 新名称
     * @return {*}
     */
    func renameSynthesisDoc(type: SynthesisType, docID: UUID, newName: String) {
        guard var docs = _synthesisResults[type],
              let idx = docs.firstIndex(where: { $0.id == docID }) else { return }
        let original = docs[idx]
        docs[idx] = SynthesisDocument(id: original.id, type: original.type, name: newName, content: original.content, createdAt: original.createdAt, size: original.size)
        synthesisResults[type] = docs
        persistResults(for: type)
    }

    /**
     * @description: 删除特定的合成文档
     * @param {SynthesisType} type 合成类型
     * @param {UUID} docID 文档 ID
     * @return {*}
     */
    func deleteSynthesisDoc(type: SynthesisType, docID: UUID) {
        guard var docs = _synthesisResults[type] else { return }
        docs.removeAll { $0.id == docID }
        synthesisResults[type] = docs
        persistResults(for: type)
    }

    /**
     * @description: 批量删除合成文档
     * @param {Set<UUID>} ids 待删除的 ID 集合
     * @return {*}
     */
    func batchDeleteSynthesisDocs(ids: Set<UUID>) {
        for type in SynthesisType.allCases {
            guard var docs = _synthesisResults[type], !docs.isEmpty else { continue }
            let originalCount = docs.count
            docs.removeAll { ids.contains($0.id) }
            if docs.count != originalCount {
                synthesisResults[type] = docs
                persistResults(for: type)
            }
        }
    }

    /**
     * @description: 物理持久化特定类型的文档列表至磁盘
     * @param {SynthesisType} type 合成类型
     * @return {*}
     */
    private func persistResults(for type: SynthesisType) {
        guard let docs = _synthesisResults[type] else { return }
        if let data = try? JSONEncoder().encode(docs) {
            UserDefaults.standard.set(data, forKey: "synthesis_docs_\(type.rawValue)")
        }
    }

    /**
     * @description: 调度 AI 合成任务，协调 TaskCenter 状态并处理并发冲突
     * @param {SynthesisType} type 合成类型
     * @param {String} combinedContent 待合成的聚合上下文内容
     * @return {*}
     */
    func performSynthesis(type: SynthesisType, combinedContent: String) {
        guard synthesisStates[type] != SynthesisStatus.generating else { return }

        let existingCount = synthesisResults[type]?.count ?? 0
        if existingCount >= maxSynthesisDocsPerType {
            synthesisStates[type] = SynthesisStatus.error(Localized.tr("synthesis.error.limitReached"))
            return
        }

        withMutation(keyPath: \.synthesisStates) {
            _synthesisStates[type] = SynthesisStatus.generating
        }
        let taskID = TaskCenter.shared.addTask(type: .synthesis, name: type.title, target: Localized.tr("sidebar.synthesis"))

        Task {
            do {
                let content: String
                switch type {
                case .mindmap:
                    content = try await AISynthesisService.shared.generateMindMap(content: combinedContent)
                case .slides:
                    content = try await AISynthesisService.shared.generatePresentation(content: combinedContent)
                case .quiz:
                    content = try await AISynthesisService.shared.generateQuiz(content: combinedContent)
                case .report:
                    content = try await AISynthesisService.shared.generateReport(content: combinedContent)
                case .infographic:
                    content = try await AISynthesisService.shared.generateInfographic(content: combinedContent)
                }

                await MainActor.run {
                    self.saveSynthesisResult(type: type, content: content)
                    TaskCenter.shared.updateTask(taskID, status: .completed)
                }
            } catch {
                await MainActor.run {
                    withMutation(keyPath: \.synthesisStates) {
                        self._synthesisStates[type] = SynthesisStatus.error(error.localizedDescription)
                    }
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                }
            }
        }
    }

    /**
     * @description: 将合成文档导出为物理文件（PDF/PPTX）
     * @param {SynthesisDocument} doc 目标文档
     * @return {URL} 导出文件的临时路径
     */
    func exportSynthesisDocument(_ doc: SynthesisDocument) async throws -> URL {
        let fileName = doc.name.replacingOccurrences(of: "/", with: "-")
                               .replacingOccurrences(of: ":", with: "-")
        switch doc.type {
        case .mindmap:
            return try await WebViewExportService.shared.exportMindmapToPDF(mermaidCode: doc.content, fileName: fileName)
        case .slides:
            return try await WebViewExportService.shared.exportToPPTX(markdown: doc.content, fileName: fileName)
        case .report, .quiz, .infographic:
            return try await WebViewExportService.shared.exportToPDF(markdown: doc.content, fileName: fileName)
        }
    }

    /**
     * @description: 彻底清空所有合成历史记录
     * @return {*}
     */
    func clearAll() {
        synthesisResults.removeAll()
        for type in SynthesisType.allCases {
            UserDefaults.standard.removeObject(forKey: "synthesis_docs_\(type.rawValue)")
            synthesisStates[type] = .idle
        }
    }

    /**
     * @description: 清理 Markdown 内容中的冗余转义字符（如 \#, \-, \[\[ 等）
     * @param {String} text 原始文本
     * @return {String} 净化后的文本
     */
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        
        // 使用正则批量移除常见的冗余转义字符，LLM 经常在生成列表、链接或特殊符号时过度转义
        // 匹配反斜杠后紧跟 Markdown 特殊字符：# ( ) [ ] { } _ ~ + - * . ! |
        let pattern = #"\\([\#\(\)\[\]\{\}\_\~\+\-\*\.\!\|])"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "$1")
        }
        
        // 特别修复 [[ ]] 的转义
        cleaned = cleaned.replacingOccurrences(of: "\\[\\[", with: "[[")
                        .replacingOccurrences(of: "\\]\\]", with: "]]")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTitle(from content: String, type: SynthesisType) -> String {
        if type == .quiz {
            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                return title
            }
        }
        
        // 使用公共格式化工具提取标题
        if let extracted = SynthesisProcessor.extractTitle(from: content) {
            return extracted
        }
        
        return type.title
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func formatDateFull(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}
