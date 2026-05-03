# Knowledge Management 详细设计文档 (Detailed Design)

本文件深入解析 Knowledge Management 核心引擎的内部实现细节。

## 1. 混合检索引擎 (Hybrid Search Engine)

### 1.1 数据流向与 RRF 融合
系统采用 **倒数排名融合 (Reciprocal Rank Fusion, RRF)** 算法来消除不同搜索引擎（FTS5 与 Vector）结果量纲不统一的问题。

**数学定义**:
对于召回结果集中的任意文档 $d$，其最终评分 $Score(d)$ 计算如下：
$$Score(d) = \sum_{r \in R} \frac{1}{k + r(d)}$$
其中：
- $R$: 检索源集合（此处为 $\{FTS, Vector\}$）。
- $r(d)$: 文档 $d$ 在该检索源中的排名索引（1-indexed）。
- $k$: 平滑常数，系统默认取值为 **60**。该值能有效平衡关键词的精确性与语义的模糊性。

### 1.3 AI 智能重排 (Rerank)
在 RRF 召回后，系统对 Top 10 候选文档执行 **AI Rerank**:
- **模型验证**: 调用 LLM 接口，根据查询词与候选文档的相关性进行二次打分。
- **排序修正**: 修正 RRF 在处理同义词或隐式关系时的排名偏差，大幅提升首位检索精度。

### 1.2 递归语义分块 (Recursive Chunking)
为了解决 RAG 中的“语义切断”问题，`RecursiveChunker` 实施了层级感知策略：
1. **优先级 1**: 查找标题分隔符 (`#`, `##`)，确保逻辑主题完整。
2. **优先级 2**: 查找段落分隔符 (`\n\n`)。
3. **窗口重叠**: 块大小固定为 $N$ (800 字符)，重叠窗口 $O = 150$ 字符（约 18.75%）。

## 2. 链接管理服务 (Link Service)

### 2.1 引用解析算法
*   **正则表达式**: `\[\[(.*?)\]\]`
*   **反向链接缓存**: 系统在内存中维护一个 `Map<PageID, [BacklinkID]>`。每当页面保存时，异步触发 `LinkRefresher` 更新该缓存，确保 UI 响应不阻塞。

## 3. 插件执行引擎 (Plugin Runtime)

### 3.1 拦截链 (Interceptor Chain)
插件执行遵循 **“管道模式 (Pipeline Pattern)”**。
*   **输入**: 原始 Markdown 字符串。
*   **变换**: `Reduce(plugins) { content, plugin in plugin.preProcess(content) }`
*   **异常隔离**: 使用 `do-catch` 包裹每个插件的执行，单个插件崩溃会自动被熔断，不影响主链路存储。

## 4. API 版本化路由 (Version Routing)

为了确保插件生态的长效兼容性，Knowledge Management 实施 **“双重版本控制”**：
1. **内核版本 (Host Version)**: 随 App 更新。
2. **能力版本 (Feature API Version)**: 独立于内核演进。
   * **路由策略**: 当内核升级至 2.0 且重构了拦截接口时，系统会维护一个 `v1_Adapter`。它将 1.0 插件的调用桥接到 2.0 实现上，确保旧插件无需重写即可运行。

## 5. 多设备冲突解铃 (Distributed LWW)

系统采用 **兰伯特时间戳 (Lamport Timestamps)** 实现分布式最终一致性：
*   **物理层逻辑**:
    ```swift
    final_version = (remote.lamport > local.lamport) ? remote : local
    ```
*   **物理模式**: 每次页面更新，`lamportTimestamp` 自动递增。在同步冲突时，通过 `WikiPage.merge(with:)` 算法自动收敛数据，避免产生重复文件或内容丢失。

## 6. 向量库同步一致性协议 (Vector DB Consistency Protocol)

为了确保核心 SQLite 数据与向量索引（Vector Index）之间的最终一致性，系统实施了以下协议：

### 6.1 事务边界与触发机制
*   **WAL (Write-Ahead Logging)**: 数据库启用 WAL 模式，确保读写不冲突。
*   **同步钩子 (Sync Hook)**: 在 `SQLiteStore` 的 `savePage` 事务提交成功后，触发 `EmbeddingManager.updateEmbedding(for:)`。
*   **ID 对齐策略**: 向量库主键必须与 SQLite 记录的 `UUID` 严格一致。

### 6.2 脏数据修复 (Reconciliation)
*   **全量核对**: App 启动时执行 `CheckConsistencyTask`。
    1. 提取 SQLite 中所有已更新但 `vector_version < page.updated_at` 的 ID。
    2. 将缺失向量的页面压入 `SyncQueue` 重新计算。
*   **重试机制**: 若向量化（NLEmbedding 调用）失败，系统会在 `last_error_log` 记录失败次数，并在 5 分钟后进行指数退避重试。

---

## 7. 数据库 Schema (L0 Detail)
```sql
CREATE TABLE pages (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT,
    vector BLOB, -- 存储 384 维浮点向量
    updated_at DATETIME
);

CREATE VIRTUAL TABLE pages_fts USING fts5(content, content='pages', content_rowid='id');
```


# 附录：专题设计补充

