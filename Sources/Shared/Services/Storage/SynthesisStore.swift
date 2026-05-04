// SynthesisStore.swift
//
// 作者: Wang Chong
// 功能说明: struct SynthesisDocument
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation

@MainActor
@Observable
final class SynthesisStore {
    struct SynthesisDocument: Codable, Identifiable, Sendable {
        let id: UUID
        let type: SynthesisType
        let name: String
        let content: String
        let createdAt: Date
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

    var synthesisStates: [SynthesisType: SynthesisStatus] = {
        var states: [SynthesisType: SynthesisStatus] = [:]
        for type in SynthesisType.allCases { states[type] = .idle }
        return states
    }()

    let maxSynthesisDocsPerType = 10

    init() {
        loadSynthesisResults()
    }

    func loadSynthesisResults() {
        for type in SynthesisType.allCases {
            let key = "synthesis_docs_\(type.rawValue)"
            if let data = UserDefaults.standard.data(forKey: key),
               let docs = try? JSONDecoder().decode([SynthesisDocument].self, from: data) {
                _synthesisResults[type] = docs
                synthesisStates[type] = .completed
            }
        }
    }

    func saveSynthesisResult(type: SynthesisType, content: String) {
        let title = extractTitle(from: content, type: type)
        let name = "\(title) - \(formatDateFull(Date()))"
        let doc = SynthesisDocument(id: UUID(), type: type, name: name, content: content, createdAt: Date())

        var existing = _synthesisResults[type] ?? []
        existing.insert(doc, at: 0)
        if existing.count > maxSynthesisDocsPerType { existing = Array(existing.prefix(maxSynthesisDocsPerType)) }
        _synthesisResults[type] = existing
        synthesisStates[type] = .completed
        persistResults(for: type)
    }

    func renameSynthesisDoc(type: SynthesisType, docID: UUID, newName: String) {
        guard var docs = _synthesisResults[type],
              let idx = docs.firstIndex(where: { $0.id == docID }) else { return }
        docs[idx] = SynthesisDocument(id: docs[idx].id, type: docs[idx].type, name: newName, content: docs[idx].content, createdAt: docs[idx].createdAt)
        _synthesisResults[type] = docs
        persistResults(for: type)
    }

    func deleteSynthesisDoc(type: SynthesisType, docID: UUID) {
        guard var docs = _synthesisResults[type] else { return }
        docs.removeAll { $0.id == docID }
        _synthesisResults[type] = docs
        persistResults(for: type)
    }

    func batchDeleteSynthesisDocs(ids: Set<UUID>) {
        for type in SynthesisType.allCases {
            guard var docs = _synthesisResults[type], !docs.isEmpty else { continue }
            let originalCount = docs.count
            docs.removeAll { ids.contains($0.id) }
            if docs.count != originalCount {
                _synthesisResults[type] = docs
                persistResults(for: type)
            }
        }
    }

    private func persistResults(for type: SynthesisType) {
        guard let docs = _synthesisResults[type] else { return }
        if let data = try? JSONEncoder().encode(docs) {
            UserDefaults.standard.set(data, forKey: "synthesis_docs_\(type.rawValue)")
        }
    }

    func performSynthesis(type: SynthesisType, combinedContent: String) {
        guard synthesisStates[type] != SynthesisStatus.generating else { return }

        let existingCount = synthesisResults[type]?.count ?? 0
        if existingCount >= maxSynthesisDocsPerType {
            synthesisStates[type] = SynthesisStatus.error(Localized.tr("synthesis.error.limitReached"))
            return
        }

        synthesisStates[type] = SynthesisStatus.generating
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
                    self.synthesisStates[type] = SynthesisStatus.error(error.localizedDescription)
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                }
            }
        }
    }

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

    func clearAll() {
        _synthesisResults.removeAll()
        for type in SynthesisType.allCases {
            UserDefaults.standard.removeObject(forKey: "synthesis_docs_\(type.rawValue)")
            synthesisStates[type] = .idle
        }
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
        let firstLine = content.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        let stripped = firstLine
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? type.title : stripped
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
