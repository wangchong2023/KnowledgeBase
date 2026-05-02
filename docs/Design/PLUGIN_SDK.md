# 智元 (ZhiMind) 插件开发指南

智元采用高度可扩展的插件化架构，允许开发者通过 Hooks 机制干预数据流、扩展 UI 以及增强 AI 能力。

---

## 1. 插件架构概览

插件系统基于 **生命周期钩子 (Hooks)** 设计。所有插件通过 `PluginRegistry` 加载，并在特定业务节点被触发。

### 核心协议：`KnowledgePlugin`

每个插件必须实现以下基础协议：

```swift
protocol KnowledgePlugin: AnyObject {
    /// 插件元数据 (包含 id, name, version 等)
    var manifest: PluginManifest { get }
    
    /// 商业化信息 (可选)
    var monetization: MonetizationInfo? { get }
    
    /// 插件加载：进行资源初始化、UI 锚点注册等
    func onLoad(context: PluginContext)
    
    /// 插件卸载：清理资源、注销钩子
    func onUnload()
}
```

---

## 2. 关键拦截点 (Interceptors)

### 2.1 拦截器插件 (InterceptionPlugin)
在内容入库前执行（例如：执行正则清洗、敏感词过滤）或在渲染前处理。

```swift
protocol InterceptionPlugin: KnowledgePlugin {
    /// 在内容入库前执行
    func preProcess(content: String) -> String
    
    /// 在内容渲染前执行
    func postProcess(content: String) -> String
}
```

### 2.2 UI 扩展钩子 (UI Extension Hook)
允许在页面详情页底部或侧边栏工具栏注入自定义视图。

---

## 3. 插件清单 (Manifest)

每个插件包必须包含一个 `manifest.json`：

```json
{
  "id": "com.zhimind.plugin.auto-tagger",
  "name": "智能自动标签",
  "version": "1.0.0",
  "description": "基于 NLP 自动为新页面提取标签",
  "permissions": ["storage.read", "llm.invoke"]
}
```

---

## 4. 最佳实践 (L0-L3 视角)

1.  **无状态设计 (Stateless)**：尽量让插件保持无状态，以支持并行执行。
2.  **异步安全**：复杂的计算逻辑应在后台线程完成，避免阻塞 L3 展现层。
3.  **错误隔离**：单个插件崩溃不应导致主程序闪退。系统通过 `do-catch` 保护每个插件的调用链。

---

## 5. 发布与分发

目前插件市场支持本地加载（开发模式）与在线市场分发。
- **本地路径**: `~/Documents/ZhiMind/Plugins/`
- **沙盒访问**: 插件需声明所需权限，用户在安装时需手动授权。
