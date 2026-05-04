# Project B: AIWorkflowStore 拆分 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract synthesis document management (~210 lines) from AIWorkflowStore (523 lines) into a separate `SynthesisStore`, reducing AIWorkflowStore to ~310 lines.

**Architecture:** Create a new `@Observable` class `SynthesisStore` owning `SynthesisDocument`, `SynthesisType`, `SynthesisStatus`, and all synthesis CRUD/generation methods. AIWorkflowStore loses all synthesis-related code. SynthesisView switches from `@Environment(AIWorkflowStore.self)` to `@Environment(SynthesisStore.self)`.

**Tech Stack:** SwiftUI `@Observable`, ServiceContainer DI (`@Inject`), UserDefaults JSON persistence

---

### Task 1: Create SynthesisStore.swift

**Files:**
- Create: `Sources/Shared/Services/Storage/SynthesisStore.swift`

- [ ] **Step 1: Write the new SynthesisStore class**

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class SynthesisStore {
    // MARK: - 合成文档模型
    struct SynthesisDocument: Codable, Identifiable, Sendable {
        let id: UUID
        let type: SynthesisType
        let name: String
        let content: String
        let createdAt: Date
    }

    enum SynthesisType: String, CaseIterable, Codable, Identifiable, Sendable {
        case mindmap, slides, quiz, report, infographic
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

    // MARK: - State

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

    @ObservationIgnored @Inject private var logService: LogServiceProtocol

    let maxSynthesisDocsPerType = 10

    init() {
        loadSynthesisResults()
    }

    // MARK: - 持久化

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
        if existing.count > 10 { existing = Array(existing.prefix(10)) }
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

    // MARK: - 生成

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

    // MARK: - 辅助

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

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
```

### Task 2: Remove synthesis code from AIWorkflowStore

**Files:**
- Modify: `Sources/Shared/Services/Storage/AIWorkflowStore.swift`

- [ ] **Step 1: Remove synthesis models from AIWorkflowStore**

Delete lines 8-72 (SynthesisDocument struct, SynthesisType enum, SynthesisStatus enum).

- [ ] **Step 2: Remove synthesis state properties**

Delete lines 121-141 (synthesisResults, synthesisStates, maxSynthesisDocsPerType).

- [ ] **Step 3: Remove synthesis methods**

Delete `loadSynthesisResults()` (lines 147-156).
Delete `saveSynthesisResult(type:content:)` (lines 158-173).
Delete `renameSynthesisDoc(type:docID:newName:)` (lines 175-183).
Delete `deleteSynthesisDoc(type:docID:)` (lines 185-192).
Delete `batchDeleteSynthesisDocs(ids:)` (lines 194-207).
Delete `performSynthesis(type:combinedContent:)` (lines 209-249).
Delete `exportSynthesisDocument(_:)` (lines 251-264).
Delete `extractTitle(from:type:)` (lines 495-515).
Delete `formatDateFull(_:)` (lines 517-522).

- [ ] **Step 4: Remove init() synthesis load loop**

Change init() from:
```swift
init() {
    loadSynthesisResults()
}
```
To:
```swift
init() {}
```

- [ ] **Step 5: Remove synthesis parts from clearAll()**

Remove these lines from clearAll():
```swift
_synthesisResults.removeAll()
for type in SynthesisType.allCases {
    UserDefaults.standard.removeObject(forKey: "synthesis_docs_\(type.rawValue)")
    synthesisStates[type] = .idle
}
```

### Task 3: Register SynthesisStore in ServiceContainer

**Files:**
- Modify: `Sources/KMApp.swift`
- Modify: `Sources/Shared/Services/Core/ServiceContainer.swift`

- [ ] **Step 1: Register SynthesisStore in ServiceContainer**

Add to the registration block where AIWorkflowStore is registered:
```swift
container.register { SynthesisStore() }
```

### Task 4: Update SynthesisView to use SynthesisStore

**Files:**
- Modify: `Sources/Shared/Views/Features/SynthesisView.swift`

- [ ] **Step 1: Replace @Environment(AIWorkflowStore.self) with SynthesisStore**

Change:
```swift
@Environment(AIWorkflowStore.self) var aiStore
```
To:
```swift
@Environment(SynthesisStore.self) var synthesisStore
```

- [ ] **Step 2: Update all type references**

Replace `AIWorkflowStore.SynthesisType` → `SynthesisStore.SynthesisType` (8 usages)
Replace `AIWorkflowStore.SynthesisDocument` → `SynthesisStore.SynthesisDocument` (5 usages)

- [ ] **Step 3: Update all method/property references**

Replace `aiStore.synthesisResults` → `synthesisStore.synthesisResults`
Replace `aiStore.synthesisStates` → `synthesisStore.synthesisStates`
Replace `aiStore.maxSynthesisDocsPerType` → `synthesisStore.maxSynthesisDocsPerType`
Replace `aiStore.performSynthesis(type:combinedContent:)` → `synthesisStore.performSynthesis(type:combinedContent:)`
Replace `aiStore.exportSynthesisDocument(...)` → `synthesisStore.exportSynthesisDocument(...)`
Replace `aiStore.deleteSynthesisDoc(...)` → `synthesisStore.deleteSynthesisDoc(...)`
Replace `aiStore.batchDeleteSynthesisDocs(...)` → `synthesisStore.batchDeleteSynthesisDocs(...)`
Replace `aiStore.renameSynthesisDoc(...)` → `synthesisStore.renameSynthesisDoc(...)`

### Task 5: Verify build

- [ ] **Step 1: Build and check for errors**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED
