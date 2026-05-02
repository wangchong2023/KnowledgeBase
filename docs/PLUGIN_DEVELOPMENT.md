# Knowledge Management 插件开发指南 (Plugin Developer Guide)

欢迎加入 Knowledge Management 生态！通过插件，你可以定制自己的知识处理管线，或为 UI 注入全新的交互方式。

## 1. 核心协议 (The Protocols)

所有插件必须符合 `KnowledgePlugin` 协议：

```swift
protocol KnowledgePlugin: AnyObject {
    var id: String { get }        // 唯一标识符，如 "com.user.my-plugin"
    var name: String { get }      // 插件名称
    var version: String { get }   // 版本号
    
    func onLoad()                 // 加载时触发：用于注册钩子或初始化资源
    func onUnload()               // 卸载时触发：用于清理资源
}
```

## 2. 拦截器插件 (Interception Hooks)

这是目前最强大的能力，允许你在内容入库或渲染前进行“深度手术”：

```swift
protocol InterceptionPlugin: KnowledgePlugin {
    // 入库前：例如将所有 "Obsidian" 自动替换为 "Knowledge Management"
    func preProcess(content: String) -> String
    
    // 渲染前：例如识别特定语法并在 UI 中渲染为特殊卡片
    func postProcess(content: String) -> String
}
```

## 3. 实战范例：自动标签插件 (Auto-Tag Plugin)

以下是一个简单的示例，它会在保存内容时，如果发现包含 "AI" 关键字，自动在末尾添加 `#AI` 标签。

```swift
class AutoTagPlugin: InterceptionPlugin {
    let id = "com.knowledge-management.autotag"
    let name = "智能自动标签"
    let version = "1.0.0"

    func onLoad() { print("AutoTag 插件已就绪") }
    func onUnload() { print("AutoTag 插件已卸载") }

    func preProcess(content: String) -> String {
        if content.contains("AI") && !content.contains("#AI") {
            return content + "\n\n#AI"
        }
        return content
    }

    func postProcess(content: String) -> String { return content }
}
```

## 4. 如何注册

目前支持在 `AppDelegate` 或 `PluginCenterView` 中手动注册：

```swift
PluginRegistry.shared.loadPlugin(AutoTagPlugin())
```

> **注意**: 未来版本将支持加载外部 `.bundle` 形式的二进制插件。
