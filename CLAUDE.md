# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

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

### Swift 6 编译器变通方案

- **`static let` 配合自定义 `Color(light:dark:)` 初始化器会失败**：Swift 6 在使用带嵌套闭包的自定义初始化器的 `static let` 属性时可能产生 "failed to produce diagnostic for expression" 错误。**变通方案**：改用 `static var` 计算属性：
  ```swift
  static var wikiCard: Color { Color(light: Color(hex: "ffffff"), dark: Color(hex: "202031")) }
  ```
- **`nonisolated(unsafe)` 用于单例**：非 `Sendable` 类中的 `static let shared` 需要该属性才能在 Swift 6 严格并发下编译通过。

### SwiftUI 图谱模式

- **浮动控件**：对浮动在内容之上的控件（Picker、缩放按钮、筛选药丸），使用 `.overlay(alignment:)`。避免使用带有 `VStack { Spacer() }` 的 ZStack 子视图——它们会创建透明的全屏层，拦截触摸事件。`.overlay(alignment:)` 仅占据其内容的固有尺寸。
- **节点定位**：仅在最外层视图上使用**单个** `.position()` 修饰符。绝不要嵌套 `.position()`——双重定位会使节点偏移约 2 倍，而 Canvas 绘制的边则保持在正确的坐标，造成视觉错位。

### 合成文档多份存储

`KMStore.synthesisResults` 是 `[SynthesisType: [SynthesisDocument]]`，每种类型最多保留 **5 份**文档（新文档插入数组头部，超出则截断）。通过 `UserDefaults` key `synthesis_docs_<type.rawValue>` 持久化 JSON 数组。

- `renameSynthesisDoc(type:docID:newName:)` — 重命名
- `deleteSynthesisDoc(type:docID:)` — 删除
- `SynthesisView` 中通过 `.contextMenu` 长按触发重命名/删除，`selectedDoc` 驱动输出 sheet

### 每日/每周洞察缓存

- **每日闪念**（`KnowledgeInsightService.generateDailyRecap`）：UserDefaults key `daily_recap_yyyyMMdd`，当天仅生成一次，`forceRefresh: true` 可强制重新生成
- **每周报告**（`KMStore.generateWeeklyInsight`）：UserDefaults key `weekly_insight_<year>_<weekOfYear>`，当周仅生成一次，`forceRefresh: true` 可强制重新生成
- Dashboard 手动下拉刷新传入 `forceRefresh: true`

### 测验生成流程

AI 输出 JSON（匹配 `QuizModel` 结构，`answer` 为 0 起始索引，0=A/1=B/2=C/3=D）→ `AISynthesisService.canDecodeAsQuizModel()` 验证格式 → `PageDetailView` 解码为 `QuizModel` → `QuizView` 交互式展示（选项标签 A/B/C/D，解释文本中数字索引替换为字母）。若 JSON 格式不匹配，回退到 Markdown 渲染。

### Mermaid 渲染模式

**始终使用程序化 `mermaid.render()`**，不要依赖 `startOnLoad: true`（不稳定）。标准模式：

1. HTML 中设置 `startOnLoad: false`，使用 `mermaid.render('id', code)` 异步渲染 SVG
2. 外层 `waitForMermaid()` 轮询 CDN 脚本加载完成
3. `WKWebView.evaluateJavaScript` 会等待 Promise 完成
4. 渲染失败时显示中文错误提示

`MermaidWebView`（展示）和 `exportMindmapToPDF()`（导出 PDF）均遵循此模式。

### WebViewExportService

`WebViewExportService`（L0 层）使用隐藏 `WKWebView` 执行 JavaScript 实现跨平台导出：
- **PDF**：`marked.parse()` 渲染 Markdown → `WKWebView.createPDF()`
- **PPTX**：解析 Markdown 为幻灯片 → `PptxGenJS` 生成 Base64 → 写入文件

### UI 框架

- 100% SwiftUI（除 `LaunchScreen.storyboard` 外无 UIKit storyboard）
- 使用 Swift 5.9 `@Observable` 宏（非 `@ObservableObject` / `@Published`）
- `NavigationSplitView` 自适应布局：iPhone 上为 TabView，iPad 上为三列布局
- 通过 `KMMac` target 支持 Mac Catalyst，带有键盘快捷键（`CommandGroup`、`.keyboardShortcut`）

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
