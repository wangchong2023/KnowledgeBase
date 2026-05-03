# 智元 (ZhiYuan) 安全规范与隐私架构 (Security & Privacy Spec)

本文档阐述了智元系统的安全设计原则、数据隔离机制及隐私保护措施。

---

## 1. 数据隔离架构 (Sandbox & Isolation)

智元严格遵循 **Apple Sandbox** 规范，并实施了以下内部隔离策略：

### 1.1 文件访问控制 (Scoped Access)
- **书签持有机制**：所有挂载的外部文件夹（Vault）均通过 `Security-Scoped Bookmarks` 进行权限持有。
- **最小特权原则**：应用仅在需要扫描或同步时开启安全域访问，完成后立即通过 `stopAccessingSecurityScopedResource` 释放。

### 1.2 插件沙盒隔离 (Plugin Sandbox)
- **拦截器隔离**：所有插件拦截任务运行在受限的非主线程中。
- **权限清单**：插件必须在 `manifest.json` 中明确声明所需的权限（如网络访问、LLM 读写）。未声明的动作将被系统核心逻辑拦截。
- **PluginContext 代理**: 插件不再直接访问 `KMStore`，而是通过 `PluginContext` 接口进行受限交互。该接口在 `PluginRegistry` 中实现，并集成了敏感操作审计。

---

## 2. 隐私保护机制 (Privacy Protection)

### 2.1 隐私模式 (Privacy Mode)
- **判定逻辑**：系统自动识别带有 `#private` 标签或 `private` 标记的知识节点。
- **渲染模糊**：在“隐私模式”开启时，系统会在 UI 渲染层对敏感内容应用 12px 的高斯模糊，必须通过生物识别或手动点击解锁方可查看。

### 2.2 离线优先向量化 (Local Embedding)
- **本地推断**：默认使用本地向量模型（Apple Neural Engine 加速），确保用户的知识片段不会上传至第三方云端进行向量化。
- **传输加密**：若用户选择使用 OpenAI 等云端模型，所有数据通过 HTTPS 传输，且不持久化于云端缓存。

---

## 3. 金库加锁 (Vault Locking)

### 3.1 物理锁定
- **数据库冻结**：当金库处于锁定状态时，`SQLiteStore` 会关闭所有连接句柄，并清除内存缓存。
- **生物识别集成**：集成 FaceID / TouchID。只有验证通过后，才会重新加载数据库加密密钥。

---

## 4. 安全审计 (Audit Logs)

- **操作审计**：所有敏感操作（如删除金库、修改安全设置、导出数据）均会记录在本地审计日志中（`LogService`），无法被插件篡改。

---

## 5. LLM 安全 (LLM Security)

### 5.1 Prompt 注入防御 (Prompt Injection Defense)
- **输入清洗**：所有传入 LLM 的用户输入均经过正则过滤，移除潜在的系统指令劫持关键词（如 "Ignore all previous instructions"）。
- **隔离执行**：AI 任务（如 Summary, Quiz）在独立进程/上下文中执行，且无权修改核心数据库状态，除非经过 `KMStore` 显式写入。
- **元数据阻断**：AI 无法获取标记为 `#private` 且未通过生物识别验证的内容。
