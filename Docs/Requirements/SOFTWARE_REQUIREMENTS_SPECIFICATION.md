# 智宇 (ZhiYu) 软件需求规格说明书 (SRS)

## 1. 性能需求 (Performance Requirements)

| 编号 | 指标项 | 目标值 (Threshold) | 验证环境 |
| :--- | :--- | :--- | :--- |
| **PR-01** | 全文搜索 (FTS5) 响应延迟 | < 100ms (10,000 节点) | iPhone 15 Pro |
| **PR-02** | 混合检索 (RAG) 链路耗时 | < 1.5s (含向量检索与 Rerank) | iPhone 15 Pro |
| **PR-03** | UI 帧率 (FPS) | 稳恒 60 FPS (图谱操作/滚动) | iPad Pro (M4) |
| **PR-04** | AI 思考指示器 (Pulse) 启动延迟 | < 200ms | iOS/macOS |
| **PR-05** | 数据库冷启动加载时间 | < 1.0s | iPhone 15 Pro |

## 2. 安全与隐私需求 (Security & Privacy)

### 2.1 数据隔离
- **SR-01**: 所有用户原始文档严禁在未经授权的情况下上传至云端。
- **SR-02**: 向量数据库 (Vector DB) 必须存储在 App 沙盒的私有目录下。

### 2.2 身份鉴权
- **SR-03**: 金库级锁定必须集成系统 `LocalAuthentication` 框架。
- **SR-04**: 插件执行环境必须实施 API 访问白名单管控，防止沙盒逃逸。

## 3. 技术规格 (Technical Specifications)

### 3.1 核心技术栈
- **UI 框架**: SwiftUI (100% Native)
- **并发模型**: Swift Actor / Structured Concurrency (Swift 6 Ready)
- **存储引擎**: SQLite 3.35.0+ (含 FTS5 插件)
- **向量引擎**: Accelerate.framework / Metal (vDSP)

### 3.2 平台兼容性
- **iOS/iPadOS**: 最小版本 17.0
- **macOS**: 最小版本 14.0 (Catalyst 兼容)
- **watchOS**: 最小版本 10.0 (独立的语音采集逻辑)

## 4. 可靠性与稳健性 (Reliability)

- **RR-01**: 数据库事务必须满足 ACID 特性，确保在进程崩溃时数据不损坏。
- **RR-02**: 系统必须支持“混沌恢复”能力（见 `SYSTEM_TEST_PLAN.md` 4.5 节）。
- **RR-03**: 内存占用在常规运行下不得超过 300MB，防止被系统 OOM 强制终止。

## 5. 本地化需求 (Localization)
- **LR-01**: 支持中英文双语切换，所有 UI 文本必须通过 `Localized.tr()` 动态加载。
- **LR-02**: 搜索算法必须支持 CJK (中日韩) 分词增强，解决 Markdown 中的中文搜索瓶颈。

## 6. 功能性需求 (Functional Requirements)

### 6.1 数据模型 (Data Models)

核心实体 `WikiPage` 字段定义：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `UUID` | 页面唯一标识，跨端同步主键 |
| `title` | `String` | 页面标题，FTS5 全文索引键 |
| `type` | `PageType` | 页面类型：`.concept` / `.fact` / `.question` / `.reference` |
| `content` | `String` | Markdown 正文，经插件 preProcess 后入库 |
| `aliases` | `[String]` | 别名列表，用于搜索联想与 `[[链接]]` 解析 |
| `tags` | `[String]` | 标签数组，支持插件自动标注 |
| `status` | `PageStatus` | `.active` / `.stub` / `.archived` / `.deprecated` |
| `confidence` | `Confidence` | 可信度：`.high` / `.medium` / `.low` / `.unverified` |
| `sources` | `[String]` | 引用来源 ID 列表 |
| `relatedPageIDs` | `[UUID]` | 双向链接关联页面 |
| `contentHash` | `String?` | 内容 SHA256 哈希，用于增量同步与去重 |
| `sourceURL` | `String?` | 原始资料链接（网页/YouTube），支持溯源 |
| `lamportTimestamp` | `Int64` | Lamport 逻辑时钟，LWW 冲突解决基础 |
| `created` / `updated` | `Date` | 创建与更新时间戳 |

### 6.2 API 契约 (LLMServiceProtocol)

LLM 服务协议定义在 `Sources/Shared/Services/Core/Protocols/LLMServiceProtocol.swift`：

| 方法 | 用途 | 约束 |
| :--- | :--- | :--- |
| `chat(query:pages:)` | 核心对话推理 | 同步返回 `ChatMessage`，含引用溯源 |
| `chatStream(query:pages:)` | 流式对话 | `AsyncThrowingStream<String, Error>`，支持逐字渲染 |
| `generate(prompt:systemPrompt:)` | 通用文本生成 | 插件 `requestAIAccess` 底层调用 |
| `smartIngest(title:rawContent:pages:)` | 智能编译 | 提取摘要、标签、关联建议 |
| `discoverPotentialLinks(content:existingTitles:)` | 链接发现 | 基于现有标题匹配潜在 `[[链接]]` |
| `foldContent(existingContent:newContent:title:)` | 智能折叠 | 增量融合新旧内容，防止知识碎片化 |
| `analyzeForRefactoring(pages:)` | 重构分析 | 返回 `[RefactorSuggestion]`，含合并/拆分建议 |
| `rewriteQuery(_:)` | 查询改写 | 将自然语言问题优化为检索友好格式 |
| `rerank(query:candidates:)` | 语义重排 | 对 Top-K 候选精排，修正向量漂移 |

### 6.3 插件接口 (Plugin Interfaces)

插件协议定义在 `Sources/Shared/Services/Plugins/PluginProtocols.swift`：

**基础协议 `KnowledgePlugin`：**
- `manifest: PluginManifest` — 元数据（id, name, version, permissions）
- `onLoad(context: PluginContext)` — 资源初始化与钩子注册
- `onUnload()` — 资源释放与钩子注销

**拦截器协议 `InterceptionPlugin`：**
- `preProcess(content:) -> String` — 入库前拦截（清洗、标注）
- `postProcess(content:) -> String` — 渲染前拦截（自定义语法）

**插件上下文 `PluginContext`：**
- `hostVersion: String` — 宿主版本号
- `log(_:)` — 统一日志输出
- `requestAIAccess(prompt:) -> String?` — 受权限管控的 LLM 访问
- `queryPages(matching:) -> [WikiPage]` — 受权限管控的页面查询

**权限枚举 `PluginPermission`：**
- `.readContent` — 读取页面内容
- `.writeContent` — 修改页面内容
- `.network` — 网络访问
- `.aiAccess` — 调用 LLM 服务

**Manifest 权限字符串：** `"storage.read"`, `"storage.write"`, `"llm.invoke"`, `"network.http"`, `"pages.read"`

### 6.4 状态管理 (State Management)

- **`KMStore`**：`@MainActor @Observable` 门面类，管理页面列表、搜索状态、导航路径、隐私模式
- **`@Inject` 依赖注入**：通过 `ServiceContainer` 解析服务实例，支持测试 Mock 替换
- **`SceneStorage` 桥接**：通过自定义 Binding 包装器将 `@Observable` 状态同步到 SwiftUI `@SceneStorage`，确保多窗口状态隔离
- **`WikiEventBus`**：发布订阅总线，`SQLiteStore` 发布 `.pageUpdated` 事件，`GraphView` 等订阅者自动刷新

### 6.5 分布式冲突解决 (LWW Strategy)

iCloud 多端同步采用 **Lamport Last-Writer-Wins (LWW)** 策略：

- **逻辑时钟**：每个 `WikiPage` 携带 `lamportTimestamp: Int64`，每次写操作递增
- **冲突检测**：`KMiCloudSyncService.resolveSyncConflict()` 比较本地与远程页面的 `lamportTimestamp` 和 `updated` 时间戳
- **合并策略**：高时间戳版本获胜；同时间戳但不同 UUID 的标题冲突保留本地版本
- **用户回调**：`onConflictDetected` 闭包允许 UI 层介入自定义冲突解决策略
- **决议枚举**：`ConflictResolution` 支持 `.keepLocal` / `.keepRemote` / `.merge`

---
*本规范受架构 4+1 视图约束，是系统验收的最高技术依据。*
