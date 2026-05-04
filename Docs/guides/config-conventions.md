# 配置与资源文件规范

## project.yml (XcodeGen)

### Target 命名

| Target | 用途 | 设备族 |
|--------|------|--------|
| `KM` | iOS 主应用 | iPhone / iPad |
| `KMMac` | Mac Catalyst | iPad / Mac |
| `KMWatch` | watchOS 独立应用 | Apple Watch |
| `KMTests` | 单元测试 | — |

### source 分组

`project.yml` 的 `sources` 按平台分组，使用 `excludes` 排除非当前 target 的文件：

```yaml
targets:
  KM:
    sources:
      - path: Sources
        excludes:
          - "Platforms/macOS/**"
          - "Platforms/watchOS/**"
```

- 新增平台相关文件时，确保放入正确平台目录并被正确 target 排除
- 共用文件放在 `Sources/Shared/` 下，不重复添加

### 依赖管理

外部包通过 `packages` 字段声明，Swift Package Manager 管理版本：

```yaml
packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 6.29.1
```

- 版本锁定使用 `from:`（语义化版本），必要时使用 `revision:` 锁定 commit
- 删除依赖时同步删除 `packages` 和 `targets.*.dependencies` 中的引用

## AppConfig.json

### 顶层分区

使用三级分层结构，按职责分区：

```json
{
  "network": { ... },       // URL、API 端点
  "performance": { ... },   // 阈值、超时、缓存
  "storage": { ... }        // 文件名、路径
}
```

- `AppConfig.swift` 中的访问方法与 JSON 分区一一对应：`getNetwork()`, `getPerformance()`, `getStorage()`
- 新增 JSON key 时必须同步更新 `AppConfig.swift` 中的访问方法
- 不使用嵌套超过 3 层

### Key 命名

分区内使用 `snake_case` 键名，语义自明：

```json
{
  "network": {
    "jina_reader_base": "https://r.jina.ai/",
    "ollama_base": "http://localhost:11434"
  },
  "performance": {
    "search_debounce_ms": 300,
    "rerank_top_limit": 10
  }
}
```

## Asset Catalog

### Colorset 命名

使用 `wiki` 前缀标识应用主题色：

- `wikiAccent` — 主题强调色
- `wikiCard` — 卡片背景色
- `wikiBackground` — 页面背景色

### AppIcon

- AppIcon 放在各 target 对应的 `Assets.xcassets/AppIcon.appiconset/` 下
- 使用 Xcode 的 AppIcon 模板，不手动修改 `Contents.json`

## 本地化文件 (.xcstrings)

### 文件分布

已按业务边界拆分，各自独立：

| 文件 | 用途 |
|------|------|
| `Graph.xcstrings` | 知识图谱视觉表达 |
| `Settings.xcstrings` | 应用配置、安全与数据管理 |
| `AITasks.xcstrings` | AI 任务中心及运行时状态反馈 |
| `InfoPlist.xcstrings` | Info.plist 权限描述文案 |

- `InfoPlist.xcstrings` 只放权限描述文案，不放 UI 文本
- 新增 UI 字符串放入对应业务域文件，不再有通用 `Localizable.xcstrings`
- `.strings` / `.stringsdict` 格式已废弃，统一使用 `.xcstrings`

## 文档文件 (.md)

### 目录结构

```
Docs/
├── Architecture/       # 架构设计文档
├── Design/             # 视觉/交互设计
├── Requirements/       # 产品需求、路线图
├── Testing/            # 测试计划、指南
└── guides/             # 编码/配置规范指南
```

### 命名规则

- 文件名：`UPPER_SNAKE_CASE.md`（如 `SYSTEM_TEST_PLAN.md`）
- 标题：文档内使用中文标题
- 同一目录下文件名前后风格一致
