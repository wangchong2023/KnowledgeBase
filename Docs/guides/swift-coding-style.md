# Swift 编码风格指南

> 本文档是 CLAUDE.md 中 `## 代码风格约定` 的详细展开。高频规范保留在 CLAUDE.md，细节约定在此。

## 类型后缀语义

不同后缀代表所属层级与职责：

| 后缀 | 层级 | 用途 | 示例 |
|------|------|------|------|
| `Store` | L1 | 数据存储操作 | `SQLiteStore`, `SettingsStore` |
| `Service` | L2 | 业务逻辑服务 | `LintService`, `CollaborationService` |
| `Manager` | L0 | 基础设施/资源管理 | `DatabaseManager`, `SecurityManager` |
| `Provider` | — | 协议级功能抽象 | `EmbeddingProvider`, `GraphDataProvider` |
| `Adapter` | — | 适配器抽象 | `LLMAdapter` |
| `Plugin` | — | 插件接口（需实现协议） | `KnowledgePlugin`, `InterceptionPlugin` |
| `Delegate` | — | 回调代理 | `CollaborationDelegate` |

- 数据库/存储操作类用 `Store`，避免 `Repository`
- 业务逻辑用 `Service`，基础设施管理用 `Manager`

## Protocol 命名

三种场景各用不同命名方式：

- **服务抽象**：`XxxProtocol` 后缀，如 `LLMServiceProtocol`, `LogServiceProtocol`
- **功能抽象**：`XxxProvider` / `XxxAdapter` / `XxxPlugin`，如 `EmbeddingProvider`, `LLMAdapter`
- **存在类型擦除**：`AnyXxx` 前缀 + 协议名，如 `AnyPageStore`

## Localization Key 格式

使用点分三级路径：`"domain.context.key"`

```swift
Localized.tr("splash.appName")                     // 页面 + 元素
Localized.tr("type.entity")                         // 分类 + 值
Localized.tr("schema.entity.field.definition")      // 域 + 上下文 + 字段
```

- 一级：功能域/页面（`splash`, `type`, `settings`, `schema`, `log`, `collab`）
- 二级：上下文（`entity`, `language`, `action`）
- 三级：具体字段/值

## CodingKeys 映射

GRDB / Codable 模型的 `CodingKeys` 使用 `snake_case` 映射，缩写展开：

```swift
enum CodingKeys: String, CodingKey {
    case id, title, type                          // 同名无需映射
    case customIcon = "custom_icon"               // camelCase → snake_case
    case sourceURL = "source_url"                 // 缩写(URL)展开
    case rawTextSnippet = "raw_snippet"           // 去掉冗余词
}
```

## Boolean 属性命名

统一前缀：`is` / `has` / `can` / `should`

```swift
let isPinned = true           // 状态判断
let hasSeenSplash = false     // 是否已发生
var canEdit: Bool             // 能力判断
var shouldRefresh: Bool       // 条件判断
```

## 补充规则

### 枚举布局风格

- 短枚举（3-5 个 case，无附加属性）：写在一行 `case a, b, c`
- 长枚举（有附加属性或方法）：每行一个 case，便于 diff

### 枚举 Raw Values

- **隐式**：仅内部使用、无 `Codable` 的枚举
- **显式**：实现了 `Codable` 的枚举

### 默认访问控制

默认 `internal`，`private` 优先于 `fileprivate`。测试通过 `@testable import` 访问。

### import 管理

- Model / Service 层：`import Foundation`，绝不导入 `SwiftUI`
- View 层：`import SwiftUI`

### 文件声明顺序

```
// MARK: - Properties         // 存储属性
// MARK: - Initialization     // init / setup
// MARK: - Public Methods     // 对外暴露的方法
// MARK: - Private Methods    // 内部实现
// MARK: - ProtocolName       // 协议遵循（每个协议一个 extension）
```

### 协议遵循用 Extension

协议实现放在独立 `extension` 中，不在类型声明体内联。`Identifiable`、`Equatable` 等无方法实现的协议可直接标注。
