# 智宇 (KM) 详细测试用例库

本文档列出了系统的关键测试用例，涵盖单元测试 (Unit) 和集成测试 (Integration)，用于保证系统的核心功能稳定性。

---

## 1. 核心存储与检索 (KMStore & Logic)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-STR-01 | KMStore | 页面创建与持久化 | 创建页面后，重启 App 或清空内存，页面数据应能从 SQLite 正确恢复。 | P0 |
| TC-STR-02 | KMStore | 数据完整性校验 | 修改数据库文件（模拟篡改），App 启动时应识别并提示错误。 | P1 |
| TC-SRC-01 | Search | 短词硬匹配 (如 "3D") | 搜索 4 字符以下短词时，标题包含该词的页面应排在最前，过滤无关语义结果。 | P0 |
| TC-SRC-02 | Search | 语义混合搜索 | 输入复杂句子，语义相似度 > 0.88 的相关页面应正确召回。 | P1 |

---

## 2. AI 助手与处理流 (AI & Ingest)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-AI-01 | LLMService | 语义摘要生成 | 提供 500 字以上文本，AI 应在 10s 内返回结构化的 Markdown 摘要。 | P0 |
| TC-AI-02 | LLMService | 发送风险与并发 | 高频点击多个 AI 功能，系统应能正确排队或取消旧任务，不崩溃且 UI 不卡顿。 | P0 |
| TC-ING-01 | IngestSvc | 网页抓取与 Markdown | 输入标准 URL，系统应能提取正文并转换为干净的 Markdown 格式。 | P1 |
| TC-ING-02 | IngestSvc | 多格式兼容性 | 导入包含代码块和表格的文档，渲染器应能保持结构完整。 | P1 |

---

## 3. 导航与交互 (UI & UX)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-NAV-01 | Navigation | [[WikiLink]] 跳转 | 在正文点击维基链接，应准确跳转到对应详情页并进入导航栈。 | P0 |
| TC-NAV-02 | Navigation | 深度链接捕获 | 通过 `wikilink://` 协议打开 App，应自动跳转至指定页面。 | P1 |
| TC-UI-01 | Dashboard | 每日闪念更新 | 知识库内容更新后，点击刷新，Daily Recap 应基于最新内容重新生成。 | P2 |

---

## 4. 安全与同步 (Security & Sync)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-SEC-01 | Privacy | 生物识别解锁 | 开启隐私模式，进入受保护页面必须通过 FaceID/TouchID 或密码。 | P0 |
| TC-SEC-02 | Crypto | 敏感数据加密 | 存储在磁盘上的”私密”页面内容不应以明文形式出现在 SQLite 文件中。 | P1 |

---

## 5. 3D 图谱引擎 (Graph Engine)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-GRF-01 | GraphLayout | 力导向布局计算 | 输入 100+ 节点与边，布局应在 200ms 内收敛，节点不重叠。 | P0 |
| TC-GRF-02 | GraphView | 2D/3D 模式切换 | 切换模式时无崩溃，视图平滑过渡，节点数据保持。 | P0 |
| TC-GRF-03 | GraphCanvas | 缩放与拖拽 | 双指缩放范围 0.5x-4.0x，拖拽不超出边界，手势流畅。 | P1 |
| TC-GRF-04 | GraphClustering | 语义聚类 | 相关页面自动聚合为簇，簇标签准确反映主题。 | P1 |
| TC-GRF-05 | GraphNode | 节点选中与高亮 | 点击节点后显示详情卡片，入/出边高亮，再次点击取消选中。 | P1 |
| TC-GRF-06 | GraphLayout | 孤立节点检测 | 无连接节点的页面应在图谱中显示为孤立点并被洞察系统识别。 | P2 |

---

## 6. 插件沙箱 (Plugin Sandbox)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-PLG-01 | PluginRegistry | 插件加载与卸载 | `onLoad` 和 `onUnload` 生命周期完整执行，资源正确释放。 | P0 |
| TC-PLG-02 | Interception | preProcess 拦截 | 插件修改内容后，入库数据为处理后版本，原始内容不被覆盖。 | P0 |
| TC-PLG-03 | Sandbox | 插件崩溃隔离 | 单个插件 `preProcess` 抛出异常时，主程序不崩溃，插件被自动熔断。 | P0 |
| TC-PLG-04 | Permissions | 权限白名单 | 插件尝试执行未声明权限的操作时被拦截，记录审计日志。 | P1 |
| TC-PLG-05 | Interception | postProcess 渲染 | 插件在渲染前修改内容后，UI 显示处理后的 Markdown。 | P1 |
| TC-PLG-06 | Market | 插件安装与更新 | 从市场安装插件后自动激活，版本更新后 `onLoad` 重新触发。 | P2 |

---

## 7. 安全金库 (Security Vault)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-VLT-01 | VaultService | 金库锁定/解锁 | 锁定后 SQLite 连接关闭，内存缓存清空；FaceID 解锁后恢复访问。 | P0 |
| TC-VLT-02 | Privacy | #private 内容模糊 | 隐私模式下标记 `#private` 的页面在列表中显示高斯模糊，不显示摘要。 | P0 |
| TC-VLT-03 | VaultService | 后台自动锁定 | App 切换至后台后，金库在设定时间内自动锁定。 | P1 |
| TC-VLT-04 | SecurityMgr | 文件完整性校验 | 外部篡改数据库文件后，HMAC-SHA256 校验失败并提示用户。 | P1 |
| TC-VLT-05 | Audit | 敏感操作审计 | 删除金库、修改安全设置等操作被完整记录，日志不可被插件篡改。 | P2 |

---

## 8. TC → XCTest 映射表

| 文档用例 ID | XCTest 类 | XCTest 方法 |
| :--- | :--- | :--- |
| TC-STR-01 | `KMStoreTests` (Tests/Shared) | `testAddPage` |
| TC-STR-02 | `KMStoreStorageTests` (Tests/Unit/Storage) | *(需补充)* |
| TC-SRC-01 | `SearchPerformanceTests` | *(需补充)* |
| TC-SRC-02 | `SearchPerformanceTests` | *(需补充 RAG 用例)* |
| TC-AI-01 | `LLMServiceTests` | *(需补充)* |
| TC-AI-02 | `LLMServiceTests` | *(需补充并发用例)* |
| TC-ING-01 | `IngestQueueTests` | *(需补充)* |
| TC-ING-02 | `IngestQueueTests` | *(需补充多格式用例)* |
| TC-NAV-01 | `KMUITests` (Tests/UITests) | *(需补充 WikiLink 跳转断言)* |
| TC-NAV-02 | `KnowledgeBaseUITests` (Tests/UI) | *(需补充 deep link 用例)* |
| TC-UI-01 | `KMTests` (Tests/Unit) | *(需补充)* |
| TC-SEC-01 | `KMUITests` (Tests/UITests) | *(需补充生物识别模拟)* |
| TC-SEC-02 | `KMServiceTests` | *(需补充加密断言)* |
| TC-GRF-01 | `GraphLayoutEngineTests` (Tests/Unit/Graph) | `testLayoutMultiplePagesCreatesNodesForAll`, `testLayoutNodePositionsAreDistinct` |
| TC-GRF-02 | `KnowledgeBaseUITests` | `testNavigateTo3DGraph` |
| TC-GRF-03 | *(待创建)* | *(待创建)* |
| TC-GRF-04 | *(待创建)* | *(待创建)* |
| TC-GRF-05 | *(待创建)* | *(待创建)* |
| TC-GRF-06 | `GraphLayoutEngineTests` (Tests/Unit/Graph) | `testLayoutIsolatedNodeHasNoEdges` |
| TC-PLG-01 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testLoadPluginRegistersAndCallsOnLoad`, `testUnloadPluginRemovesAndCallsOnUnload` |
| TC-PLG-02 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testInterceptionPluginIsRegisteredAsInterceptor` |
| TC-PLG-03 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testPluginExceptionDoesNotCrashRegistry` |
| TC-VLT-01 | `VaultSecurityTests` (Tests/Unit/Security) | `testLockSetsIsLockedToTrue`, `testLockUnlockCycle` |
| TC-VLT-02 | *(待创建)* | *(待创建)* |
| TC-VLT-03 | `VaultSecurityTests` (Tests/Unit/Security) | `testMultipleLockCallsStayLocked` |
| TC-VLT-04 | `KMServiceTests` | *(需补充)* |
| TC-VLT-05 | *(待创建)* | *(待创建)* |

> 标注”待创建”的条目表示对应模块尚无测试文件，需要在 `Tests/` 中新增测试类。
