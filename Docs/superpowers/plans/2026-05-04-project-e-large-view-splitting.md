# 项目 E：大文件拆分

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 PageDetailView (850行) 和 ChatView (481行) 拆分为可维护的子部件。

**Architecture:** 两个 View 均已存在对应的 ViewModel。拆分的重心是将独立子视图提取到 `Views/Pages/Subviews/` 和 `Views/Features/` 中。只提取子视图，不改动逻辑。每次提取后编译验证。

**Tech Stack:** Swift 6, SwiftUI

---

### Task E1: PageDetailView (850→~550行)

**Files:**
- Modify: `Sources/Shared/Views/Pages/PageDetailView.swift:725-848`
- Modify: `Sources/Shared/Views/Pages/PageDetailView.swift:696-724`
- Create: `Sources/Shared/Views/Pages/Subviews/SnapshotHistoryView.swift`
- Create: `Sources/Shared/Views/Pages/Subviews/RelatedPageDropDelegate.swift`

**E1.1: 提取 SnapshotHistoryView**

PageDetailView.swift 末尾（725-848行）包含完全独立的 `SnapshotHistoryView` 和 `private struct SnapshotDetailView`。提取到 `Sources/Shared/Views/Pages/Subviews/SnapshotHistoryView.swift`：

```swift
import SwiftUI

struct SnapshotHistoryView: View {
    let page: WikiPage
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var history: [SnapshotInfo] = []
    @State private var selectedSnapshot: SnapshotInfo?
    @State private var compareContent: String?
    // ... 完整原有 body、onAppear ...
}

struct SnapshotDetailView: View {
    let page: WikiPage
    let snapshot: SnapshotInfo
    let content: String
    let onRollback: () -> Void
    @Environment(\.dismiss) private var dismiss
    // ... 完整原有 body ...
}
```

从 PageDetailView.swift 删除第725-848行。

**E1.2: 提取 RelatedPageDropDelegate**

从 PageDetailView.swift:696-724 提取到 `Sources/Shared/Views/Pages/Subviews/RelatedPageDropDelegate.swift`。

**E1.3: 编译验证**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES 2>&1 | tail -10
```

---

### Task E2: ChatView (481→~350行)

**Files:**
- Modify: `Sources/Shared/Views/Features/ChatView.swift:211-267`
- Create: `Sources/Shared/Views/Features/ChatWelcomeView.swift`

**E2.1: 提取 ChatWelcomeView 和 SuggestionGroupView**

从 ChatView.swift 提取 `chatWelcome()` 方法和 `suggestionGroup()` 方法到 `Sources/Shared/Views/Features/ChatWelcomeView.swift`。

`chatWelcome()`（211-267行）转为独立 `ChatWelcomeView` 结构体：
```swift
import SwiftUI

struct ChatWelcomeView: View {
    let isSheet: Bool
    let promptService: PromptService
    let chatVM: ChatViewModel
    let isGeneratingAIQuestions: Bool
    let onSend: (String) -> Void
    
    var body: some View {
        // 原 chatWelcome body
    }
}

struct SuggestionGroupView: View {
    let title: String
    let icon: String
    let queries: [String]
    let color: Color
    let onSend: (String) -> Void
    
    var body: some View {
        // 原 suggestionGroup body
    }
}
```

ChatView.swift 中替换引用：`chatWelcome()` → `ChatWelcomeView(...)`，`suggestionGroup(...)` → `SuggestionGroupView(...)`。

**E2.2: 编译验证**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES 2>&1 | tail -10
```
