# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导，回复问题和任务规划采用简体中文。

## 参考指南

| 指南 | 内容 |
|------|------|
| [swift-coding-style.md](Docs/guides/swift-coding-style.md) | 命名、Protocol、Localization key、CodingKeys、Boolean 前缀等 Swift 编码约定 |
| [config-conventions.md](Docs/guides/config-conventions.md) | project.yml、AppConfig.json、Asset Catalog、.xcstrings、文档目录规范 |
| [implementation-patterns.md](Docs/guides/implementation-patterns.md) | Swift 6 变通方案、图谱模式、合成文档、缓存策略、Mermaid、UI 框架等 |

## 项目概览

智元 (ZhiYuan) — 面向 iOS/macOS/watchOS 的 AI 原生知识管理应用，基于 Karpathy 的 LLM Wiki 方法论构建。不仅是一个 Markdown 编辑器，更是一个 RAG 闭环系统：语义分块 → 混合 FTS5+向量存储 → AI 合成实验室（含深度引用）。

## 构建与开发

```bash
# 从 project.yml 生成 Xcode 项目（配置变更后必须执行）
xcodegen generate

# 构建 iOS
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS'

# 构建 macOS (Catalyst)
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'platform=macOS'

# 构建 watchOS
xcodebuild build -project KM.xcodeproj -scheme KMWatch -destination 'generic/platform=watchOS'

# 列出可用模拟器（CI 环境可能与本机不同）
xcodebuild -project KM.xcodeproj -scheme KM -showdestinations | grep simulator

# 运行单元测试（设备名需替换为 -showdestinations 中列出的）
xcodebuild test -project KM.xcodeproj -scheme KM -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES

# 运行单个测试类
xcodebuild test -project KM.xcodeproj -scheme KM -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KMTests/KMStoreTests

# 代码检查（需安装 SwiftLint: brew install swiftlint）
swiftlint --strict
```

## 架构：L0–L3 严格分层

依赖规则：**上层依赖下层，绝不可反向。** 跨层访问必须通过协议。

| 层级 | 名称 | 内容 |
|-------|------|-----------------|
| **L3** | 表现层 | SwiftUI Views、`@Observable` ViewModels、导航 |
| **L2** | 领域/功能层 | 业务逻辑服务 — `KnowledgeInsightService`、`AISynthesisService`、`IngestService` |
| **L1** | 服务层 | 数据访问与 AI 适配器 — `KMStore`、`LLMClient`、`EmbeddingManager`、`LinkScraper` |
| **L0** | 基础设施层 | 存储引擎、网络、Keychain、Logger、OS 工具 |

## 关键模式

### 依赖注入 — `@Inject` 属性包装器

服务通过 `ServiceContainer`（服务定位器模式）在 `KMApp.init()` 中注册。在任何 View 或其他服务中使用：

```swift
@Inject var store: KMStore
```

`@Inject` 包装器从 `ServiceContainer.shared` 解析。服务必须在使用前注册——未注册会导致 `fatalError`。

### 并发

- 严格并发检查**已启用**（`SWIFT_STRICT_CONCURRENCY: complete` — Swift 6 模式）
- 优先使用 `async/await` 和 `actor`；绝不使用锁或信号量
- UI 绑定代码必须标注 `@MainActor`
- 非 `Sendable` 单例类（如 `PPTXGenerator`），将 `static let shared` 标记为 `nonisolated(unsafe)`：
  ```swift
  nonisolated(unsafe) static let shared = PPTXGenerator()
  ```

> 实现细节见 [Docs/guides/implementation-patterns.md](Docs/guides/implementation-patterns.md)（Swift 6 变通方案、图谱模式、合成文档、缓存策略、测验流程、Mermaid、WebViewExport、UI 框架）。

## 项目结构（关键路径）

```
Sources/
├── KMApp.swift                # @main 入口点，服务注册
├── Shared/
│   ├── Models/                # WikiPage、GraphModels、PageSchema、AppConfig、CollaborationModels
│   ├── Services/
│   │   ├── Core/              # ServiceContainer（DI）、LLMServiceProtocol、EmbeddingProvider、LLMStrategy
│   │   ├── Storage/           # KMStore、SQLiteStore、VaultService、BackupService
│   │   ├── AI/                # LLMService、LLMClient、EmbeddingManager、AISynthesisService、IngestQueue
│   │   ├── Logic/             # KnowledgeInsightService、LinkService、RecursiveChunker
│   │   ├── Processors/        # LinkScraperService、MarkdownParser、OCRService、PDFService、SpeechService
│   │   ├── Graph/             # GraphClusteringService、GraphLayoutEngine
│   │   ├── Sync/              # iCloudSyncManager、KMiCloudSyncService、FileSystemSyncService
│   │   ├── Plugins/           # PluginRegistry、PluginProtocols、PluginMarketService
│   │   ├── Infrastructure/    # LogService、HapticManager、SecurityManager、PerformanceService、WebViewExportService 等
│   │   ├── Feature/           # CollaborationService、IngestService、LintService、TaskCenter、UndoService
│   │   ├── Gamification/      # MedalService
│   │   └── System/            # ActivityService、WikiEventBus
│   ├── Views/
│   │   ├── Core/              # ContentView、Navigation、Dashboard、Search
│   │   ├── Pages/             # 页面列表、详情、历史
│   │   ├── Editors/           # Markdown 编辑器、源码模式
│   │   ├── Features/          # Graph3DView、GraphView、AI 合成视图
│   │   ├── Components/        # 可复用 UI 组件（chips、breadcrumbs 等）
│   │   ├── CommandPalette/    # Cmd+K 命令面板
│   │   └── Settings/          # 设置视图
│   └── Infrastructure/        # ThemeManager、Localization、CJK 支持、跨平台辅助
├── Platforms/iOS/             # iOS 特定代码
├── Platforms/macOS/           # macOS 特定代码
├── Platforms/watchOS/         # WatchContentView、WatchDictationView、WatchWidgets
└── Resources/AppConfig.json   # 运行时配置
Tests/
├── Unit/                      # 模型、服务、存储、AI 测试 + RAG 黄金集评估
├── Integration/               # RAGPipelineTests
├── UI/ + UITests/              # UI 自动化测试
├── SnapshotTests/              # Point-Free 快照测试
├── Performance/               # 搜索性能基准测试
├── Boundary/                  # 边界情况测试（ingest queue）
└── Platforms/                 # Watch 连接测试
```

## Targets

- **KM** — iOS 应用（iPhone/iPad），主 target
- **KMMac** — Mac Catalyst 应用，`SUPPORTS_MACCATALYST: YES`，仅 iPad/Mac 设备族
- **KMWatch** — 独立 watchOS 应用，支持听写和小组件
- **KMTests** — 单元测试 bundle，依赖 KM + SnapshotTesting 包

## 提交规范

使用 Conventional Commits 格式（可以使用中文描述）：

- `feat:` — 新功能
- `fix:` — 缺陷修复
- `docs:` — 文档更新
- `refactor:` — 代码重构
- `perf:` — 性能优化

分支命名：`feature/*`、`hotfix/*`、`bugfix/*`。功能开发合入 `develop`，`main` 为稳定发布分支。

## 代码风格约定

> 完整细节见 [Docs/guides/swift-coding-style.md](Docs/guides/swift-coding-style.md)（命名、Protocol、Localization key、CodingKeys 等）。
> 配置文件规范（project.yml、AppConfig.json、xcassets 等）见 [Docs/guides/config-conventions.md](Docs/guides/config-conventions.md)。

### 核心约定

| 规则 | 说明 |
|------|------|
| `import` 管理 | Model/Service 层 `import Foundation`，绝不导入 `SwiftUI`；View 层 `import SwiftUI` |
| 枚举 Raw Values | 无 `Codable` 用隐式，有 `Codable` 用显式 |
| 协议遵循用 Extension | 协议实现放独立 `extension`，不在类型声明体内联 |

### 注释规范

统一使用**简体中文**书写所有注释：

- **文档注释（`///`）**：用于公开 API、协议方法、类型定义，供 Xcode Quick Help 显示。用中文。
- **实现注释（`//`）**：用于内部逻辑说明。用中文。
- **MARK 标签**：使用 `// MARK: - 中文标题` 格式，`-` 分隔符不可省略。
- **TODO/FIXME**：`// TODO: 中文说明` / `// FIXME: 中文说明`
- **英文术语保留**：专有名词、API 名、框架名等保留英文原文（如 `// 缓存失效后强制重新计算`）。

> `///` 解释"为什么"，`//` 解释"怎么做"。一行能读懂的代码不需要注释。
