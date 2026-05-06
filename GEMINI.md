# 智宇 (ZhiYu) - AI 原生知识管理应用

智宇 (ZhiYu) 是一款面向 iOS、macOS 和 watchOS 的 AI 原生知识管理应用，基于 Andrej Karpathy 的 LLM Wiki 方法论构建。它不仅仅是一个 Markdown 编辑器，更是一个完整的 RAG (Retrieval-Augmented Generation) 闭环系统。

## 项目概览

- **核心目标**：语义分块 → 混合 FTS5+向量存储 → AI 合成实验室（深度引用）。
- **主要技术栈**：
  - **语言**：Swift 6 (开启严格并发检查)
  - **UI 框架**：SwiftUI (全平台统一代码库)
  - **存储**：SQLite (GRDB.swift) + 向量存储
  - **AI**：本地/远程 LLM 适配，RAG 管道
  - **工程化**：XcodeGen (`project.yml`), SwiftLint, String Catalog (`.xcstrings`)

## 构建与开发

所有构建日志应存放在 `build/` 目录下。

```bash
# 从 project.yml 生成 Xcode 项目（配置变更后必须执行）
xcodegen generate

# 同步本地化词条（分表合并到主表）
python3 Tools/update_localization.py

# 构建 iOS (iPhone/iPad)
xcodebuild build -project KM.xcodeproj -scheme KM -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/ios_build.log 2>&1

# 构建 macOS (Catalyst)
xcodebuild build -project KM.xcodeproj -scheme KMMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/mac_build.log 2>&1

# 构建 watchOS
xcodebuild build -project KM.xcodeproj -scheme KMWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/watch_build.log 2>&1

# 运行单元测试
xcodebuild test -project KM.xcodeproj -scheme KM -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > build/test_results.log 2>&1
```

## 架构规范 (L0–L3 严格分层)

项目遵循严格的依赖规则：**上层依赖下层，严禁反向依赖**。跨层访问必须通过协议。

| 层级 | 名称 | 内容 |
|-------|------|-----------------|
| **L3** | 表现层 | SwiftUI Views, `@Observable` ViewModels, 路由导航 |
| **L2** | 领域/功能层 | 业务逻辑服务 (`KnowledgeInsightService`, `AISynthesisService`, `IngestService`) |
| **L1** | 服务层 | 数据访问与 AI 适配器 (`KMStore`, `LLMClient`, `EmbeddingManager`) |
| **L0** | 基础设施层 | 存储引擎 (SQLite), 网络 (Network), 安全 (Keychain, SecurityManager, Logger) |

## 开发约定

### 1. 依赖注入 (DI)
使用 `ServiceContainer` 模式和 `@Inject` 属性包装器。所有服务必须在 `KMApp.init()` 中注册。
```swift
@Inject var store: KMStore
```

### 2. 并发模型 (Swift 6)
- 启用 `SWIFT_STRICT_CONCURRENCY: complete`。
- 优先使用 `async/await` 和 `actor`；避免使用传统锁。
- UI 绑定代码必须标注 `@MainActor`。
- 非 `Sendable` 的单例常量需标注 `nonisolated(unsafe)`。

### 3. 注释与文档
- **统一使用简体中文**书写所有注释。
- **文档注释 (`///`)**：解释“为什么”，用于公开 API。
- **实现注释 (`//`)**：解释“怎么做”，用于内部逻辑。
- **MARK 标签**：`// MARK: - 中文标题`。

### 4. 本地化 (L10n)
- 使用 `L10n` 结构体进行类型安全访问。
- 业务逻辑中使用 `Localized.tr("key", table: "TableName")`。

### 5. 编码风格
- 遵循 `Docs/guides/swift-coding-style.md`。
- `import` 管理：Model/Service 层 `import Foundation`（严禁导入 `SwiftUI`）；View 层 `import SwiftUI`。
- 协议遵循放在独立 `extension` 中。

### 6. 脚本管理规范
- **长期工具**：存放在 `Tools/` 目录下。
- **临时脚本**：存放在 `Tools/Temp/` 目录下，使用后需及时清理。
- **文档维护**：新增或修改脚本后，必须同步更新 `Tools/README.md`。

## 提交规范
使用 Conventional Commits 格式：
- `feat:` (新功能), `fix:` (缺陷修复), `docs:` (文档), `refactor:` (重构), `perf:` (优化)。

## 关键文件路径
- `Sources/KMApp.swift`: 应用入口与服务注册。
- `Sources/Shared/Services/Core/ServiceContainer.swift`: DI 容器实现。
- `Sources/Shared/Models/`: 核心领域模型。
- `Sources/Shared/Views/`: 跨平台 SwiftUI 视图。
- `Tools/`: 开发者辅助工具（同步、模拟器、MockServer）。
- `project.yml`: XcodeGen 项目定义。
