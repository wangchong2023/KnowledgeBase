# 项目 C：跨层 SwiftUI import 清理

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除服务和模型层对 SwiftUI 的所有 import，恢复分层依赖规则。

**Architecture:** 三层策略：① 模型层 `Color` 属性替换为 `colorName: String`（返回 "blue", "green" 等），视图层通过扩展转换；② 内嵌视图从服务文件提取到 `Views/Components/`；③ 仅因 `@Observable` 而导入 SwiftUI 的改为 `import Observation`。

**Tech Stack:** Swift 6, SwiftUI, Observation framework

**前置检查:** 每次改动后运行 `xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES` 验证编译。

---

### Task C1: 模型层 Color 属性替换

**Files:**
- Modify: `Sources/Shared/Models/PageType.swift:75-82,100-106`
- Modify: `Sources/Shared/Models/LintIssue.swift:67-73`
- Modify: `Sources/Shared/Models/LogAction.swift:48-62`
- Create: `Sources/Shared/Views/Components/ModelColorView.swift`

当前模型层每个 `var color: Color` 返回系统颜色（`.green`, `.red` 等）。将其替换为 `var colorName: String`，并在 View 层提供转换。

**C1.1: PageType.swift — PageStatus.color 和 Confidence.color**

当前代码（PageType.swift:75-82）：
```swift
var color: Color {
    switch self {
    case .active: return .green
    case .stub: return .yellow
    case .needsUpdate: return .orange
    case .deprecated: return .red
    }
}
```

改为：
```swift
var colorName: String {
    switch self {
    case .active: return "green"
    case .stub: return "yellow"
    case .needsUpdate: return "orange"
    case .deprecated: return "red"
    }
}
```

同理 Confidence (PageType.swift:100-106)：
```swift
var colorName: String {
    switch self {
    case .high: return "green"
    case .medium: return "yellow"
    case .low: return "red"
    }
}
```

完成后删除 `import SwiftUI`（第11行）。PageType.swift 仍需 `import GRDB`。

**C1.2: LintIssue.swift — LintSeverity.color**

当前代码（LintIssue.swift:67-73）：
```swift
var color: Color {
    switch self {
    case .error: return .red
    case .warning: return .orange
    case .info: return .blue
    }
}
```

改为：
```swift
var colorName: String {
    switch self {
    case .error: return "red"
    case .warning: return "orange"
    case .info: return "blue"
    }
}
```

删除 `import SwiftUI`（第13行）。

**C1.3: LogAction.swift — LogAction.color**

当前代码（LogAction.swift:48-62）每个 case 返回 `.green`, `.blue` 等 Color 值。改为 `var colorName: String`，每个 case 返回对应名称字符串（"green", "blue", "red", "teal", "purple", "yellow", "indigo", "gray"）。

完成后删除 `import SwiftUI`（第11行）。

**C1.4: 创建 Color 转换扩展**

创建 `Sources/Shared/Views/Components/ModelColorView.swift`：

```swift
import SwiftUI

extension Color {
    static func fromModelColorName(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "pink": return .pink
        case "gray": return .gray
        default: return .gray
        }
    }
}
```

**C1.5: 更新 View 文件中的引用**

搜索所有用到 `.color` 的地方（模型层的，不是 wikiColor 系列）并替换：
```bash
grep -rn 'status\.color\|conf\.color\|severity\.color\b' Sources/Shared/Views/
grep -rn 'LogAction.*\.color\|\.color' Sources/Shared/Views/ | grep -v 'wikiColor\|wikiAccent\|wikiCard\|wikiBackground\|wikiBorder\|wikiSecondary\|wikiText\|Color\.\|\.colors\b\|accentColor\|foregroundColor\|background'
```

在 PageDetailView.swift 中：`status.color` → `Color.fromModelColorName(status.colorName)`
在 LintView.swift 中：`severity.color` → `Color.fromModelColorName(severity.colorName)`
在 LogView.swift 中：`action.color` → `Color.fromModelColorName(action.colorName)`
在 ChatView.swift / 其他：检查 `Confidence.color` 引用

---

### Task C2: 从服务文件提取内嵌 View

**Files:**
- Modify: `Sources/Shared/Services/Infrastructure/PerformanceService.swift:103-268`
- Modify: `Sources/Shared/Services/Infrastructure/OnboardingService.swift:77-128`
- Modify: `Sources/Shared/Services/Infrastructure/KMKeyboardShortcuts.swift:60-80`
- Modify: `Sources/Shared/Services/Infrastructure/AccessibilityService.swift:79-130`
- Create: `Sources/Shared/Views/Components/PerformanceDashboardView.swift`
- Create: `Sources/Shared/Views/Components/OnboardingOverlay.swift`
- Create: `Sources/Shared/Views/Components/KeyboardShortcutsModifier.swift`
- Create: `Sources/Shared/Views/Components/AccessibilityViewExtensions.swift`

**C2.1: 提取 PerformanceDashboardView**

从 PerformanceService.swift 删除第103-268行（PerformanceDashboardView、MetricCardView、TimingRowView）。创建新文件包含这些视图。PerformanceService.swift 删除 `import SwiftUI`。

**C2.2: 提取 OnboardingOverlay**

从 OnboardingService.swift 删除第77-128行。创建新文件。OnboardingService.swift 删除 `import SwiftUI` 和 `import Combine`。

**C2.3: 提取 KeyboardShortcutsViewModifier**

从 KMKeyboardShortcuts.swift 删除第60-80行（KeyboardShortcutsViewModifier + View extension）。创建新文件。KMKeyboardShortcuts.swift 删除 `import SwiftUI`。

**C2.4: 提取 Accessibility View Extensions**

从 AccessibilityService.swift 删除第79-130行（View extension、AccessibilityReduceMotionKey、ConditionalAnimationModifier）。创建新文件。AccessibilityService.swift 删除 `import SwiftUI`。

**C2.5: 编译验证**

---

### Task C3: 服务层 Color 属性迁移

**Files:**
- Modify: `Sources/Shared/Services/Graph/GraphClusteringService.swift:24,54`
- Modify: `Sources/Shared/Services/Processors/PDFService.swift:82-91`
- Modify: `Sources/Shared/Services/Feature/LintService.swift:25-32`
- Modify: `Sources/Shared/Services/Storage/SynthesisStore.swift:59-67`

**C3.1: GraphClusteringService**

- `let color: SwiftUI.Color` → `let colorName: String`
- 颜色数组 `[SwiftUI.Color]` → `[String]`
- 删除 `import SwiftUI`
- 更新调用处：`colorName` 在 View 层通过 `Color.fromModelColorName(...)` 转换

**C3.2: PDFService.PDFHighlight**

- `var highlightColor: Color` → `var highlightColorName: String { color }`
- 删除 `import SwiftUI`
- 搜索 `\.highlightColor` 在 Views 中的引用并替换

**C3.3: LintService.HealthLevel**

- `var color: Color` → `var colorName: String`
- 删除 `import SwiftUI`
- 搜索 `HealthLevel.*\.color` 在 Views 中的引用并替换

**C3.4: SynthesisStore.SynthesisType**

- `var formatColor: Color` → `var formatColorName: String`
- `import SwiftUI` → `import Observation`
- 搜索 `\.formatColor` 在 Views 中的引用并替换

---

### Task C4: 不必要的 SwiftUI import 替换

**Files:**
- Modify: `Sources/Shared/Services/Storage/SettingsStore.swift:11` — `import SwiftUI` → `import Observation`
- Modify: `Sources/Shared/Services/Storage/IngestStore.swift:11` — `import SwiftUI` → `import Observation`
- Modify: `Sources/Shared/Services/Storage/SearchStore.swift:11` — `import SwiftUI` → `import Observation`

这三个文件 `import SwiftUI` 仅为了使用 `@Observable` 宏。Swift 5.9+ 中 `@Observable` 可从 `import Observation` 获得。

---

### Task C5: 混合服务清理

**Files:**
- Modify: `Sources/Shared/Services/Storage/VaultStorageSecurityService.swift:13,51,62`
- Modify: `Sources/Shared/Services/Infrastructure/WebViewExportService.swift:11`
- Evaluate: `Sources/Shared/Services/Processors/OCRService.swift:12`

**C5.1: VaultStorageSecurityService** — `withAnimation` 包裹改为直接赋值，删除 `import SwiftUI`

**C5.2: WebViewExportService** — 检查是否实际引用 SwiftUI 类型。若无，删除 import。

**C5.3: OCRService** — 尝试删除 `@preconcurrency import SwiftUI`。若编译失败则保留并加注释。

---

### Task C6: 编译验证与文档更新

**C6.1: 全局编译并修复错误**

```bash
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES 2>&1 | tail -30
```

**C6.2: 更新架构文档**

更新 `Docs/Architecture/LAYERING_L0_L3.md` 中跨层违规表格：模型层 SwiftUI import 3→0，服务层从2降至实际值（基础设施层保留合理 import）。
