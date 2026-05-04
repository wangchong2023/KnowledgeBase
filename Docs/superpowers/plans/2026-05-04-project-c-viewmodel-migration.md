# Project C: ViewModel 迁移（第一轮）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract business logic and UI state from 3 large View files into dedicated `@MainActor @Observable` ViewModels, reducing View complexity and enabling testability.

**Architecture:** Create `GraphViewModel`, `PageDetailViewModel`, `ChatViewModel` following the existing `iCloudSyncCoordinator` pattern (`@MainActor @Observable final class`). Views receive the ViewModel via `@State` and delegate state management.

**Tech Stack:** SwiftUI `@Observable`, ServiceContainer DI (`@Inject`), async/await

---

### Task 1: Create GraphViewModel

**Files:**
- Create: `Sources/Shared/ViewModels/GraphViewModel.swift`
- Modify: `Sources/Shared/Views/Features/GraphView.swift`
- Modify: `Sources/Shared/Views/Features/Graph3DView.swift` (may share state)

- [ ] **Step 1: Create ViewModels directory (if not exists)**

```bash
mkdir -p Sources/Shared/ViewModels
```

- [ ] **Step 2: Create GraphViewModel.swift**

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class GraphViewModel {
    var selectedNodeID: UUID?
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var graphSize: CGSize = CGSize(width: 400, height: 600)
    var scale: CGFloat = 1.0
    var lastScale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var isAnimating = false
    var showLegend = false
    var showInsights = false
    var useClustering = false
    var show3D = false
    var filterType: PageType?
    var insightSurprising: [UUID] = []
    var insightOrphans: [UUID] = []
    var insightSparse: [UUID] = []
    var insightBridges: [UUID] = []

    func getFilteredNodes() -> [GraphNode] {
        guard let filter = filterType else { return nodes }
        return nodes.filter { $0.type == filter }
    }

    func getFilteredEdges(for filteredNodes: [GraphNode]) -> [GraphEdge] {
        guard filterType != nil else { return edges }
        let filteredIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { edge in
            filteredIDs.contains(edge.source) && filteredIDs.contains(edge.target)
        }
    }
}
```

- [ ] **Step 3: Update GraphContainerView in GraphView.swift**

In `GraphView.swift`:
- Replace all 17 `@State` property declarations with `@State private var viewModel = GraphViewModel()`
- Replace all direct property accesses with `viewModel.` prefix
- Replace calls to `getFilteredNodes()` → `viewModel.getFilteredNodes()`
- Replace calls to `getFilteredEdges(...)` → `viewModel.getFilteredEdges(...)`
- Keep `tooltipManager` as `@StateObject` (it has its own lifecycle)

- [ ] **Step 4: Verify build**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: BUILD SUCCEEDED

### Task 2: Create PageDetailViewModel

**Files:**
- Create: `Sources/Shared/ViewModels/PageDetailViewModel.swift`
- Modify: `Sources/Shared/Views/Pages/PageDetailView.swift`

- [ ] **Step 1: Create PageDetailViewModel.swift**

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class PageDetailViewModel {
    var page: WikiPage
    var isEditing = false
    var showBacklinks = false
    var showDeleteConfirmation = false
    var showAliasEditor = false
    var newAlias = ""
    var showIconPicker = false
    var showSnapshotHistory = false

    @ObservationIgnored @Inject private var store: KMStore

    init(page: WikiPage) {
        self.page = page
    }

    var backlinks: [WikiPage] {
        store.pages.filter { page in
            page.content.contains("[[\(self.page.title)]]") || page.content.contains("[[\(self.page.title)|")
        }
    }

    func deletePage() {
        store.deletePage(page)
    }

    func addAlias() {
        let trimmed = newAlias.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !page.aliases.contains(trimmed) else { return }
        var updated = page
        updated.aliases.append(trimmed)
        store.savePage(updated)
        page = updated
        newAlias = ""
    }

    func removeAlias(_ alias: String) {
        var updated = page
        updated.aliases.removeAll { $0 == alias }
        store.savePage(updated)
        page = updated
    }

    func togglePin() {
        var updated = page
        updated.isPinned.toggle()
        store.savePage(updated)
        page = updated
    }

    func updateType(_ type: PageType) {
        var updated = page
        updated.type = type
        store.savePage(updated)
        page = updated
    }

    func updateStatus(_ status: PageStatus) {
        var updated = page
        updated.status = status
        store.savePage(updated)
        page = updated
    }

    func updateConfidence(_ confidence: Double) {
        var updated = page
        updated.confidence = confidence
        store.savePage(updated)
        page = updated
    }
}
```

- [ ] **Step 2: Update PageDetailView to use PageDetailViewModel**

In `PageDetailView.swift`:
- Replace `@State var page: WikiPage` + all 6 `@State` UI toggles with `@State private var viewModel: PageDetailViewModel`
- Initialize viewModel in `.task` or `onAppear` with `viewModel = PageDetailViewModel(page: page)`
- Replace `backlinks` computed property → `viewModel.backlinks`
- Replace toolbar action calls → `viewModel` methods

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: BUILD SUCCEEDED

### Task 3: Create ChatViewModel

**Files:**
- Create: `Sources/Shared/ViewModels/ChatViewModel.swift`
- Modify: `Sources/Shared/Views/Features/ChatView.swift`

- [ ] **Step 1: Create ChatViewModel.swift**

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var inputText = ""
    var isExporting = false
    var showExportSuccess = false
    var showAISuggestions = false
    var insightfulQuestions: [String] = []

    @ObservationIgnored @Inject private var aiSynthesis: AISynthesisService

    func loadInsightfulQuestions(pages: [WikiPage]) async {
        do {
            insightfulQuestions = try await aiSynthesis.generateInsightfulQuestions(pages: pages)
        } catch {
            insightfulQuestions = []
        }
    }

    func exportChat(history: [ChatMessage]) {
        isExporting = true
        let md = history.map { msg in
            let role = msg.role == .user ? "You" : "AI"
            return "## \(role)\n\n\(msg.content)"
        }.joined(separator: "\n\n---\n\n")

        Task {
            defer { isExporting = false }
            do {
                let url = try await WebViewExportService.shared.exportToPDF(markdown: md, fileName: "Chat_Export")
                showExportSuccess = true
            } catch {
                // caller handles error display
            }
        }
    }
}
```

- [ ] **Step 2: Update ChatView to use ChatViewModel**

In `ChatView.swift`:
- Replace `@State private var inputText` with `@State private var chatVM = ChatViewModel()`
- Replace `inputText` → `chatVM.inputText`
- Replace AI suggestion loading with `chatVM.loadInsightfulQuestions(pages:)`
- Replace export logic with `chatVM.exportChat(history:)`

- [ ] **Step 3: Verify build**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: BUILD SUCCEEDED

### Task 4: Update project.pbxproj for new ViewModel files

- [ ] **Step 1: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 2: Final build verification**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```
Expected: BUILD SUCCEEDED
