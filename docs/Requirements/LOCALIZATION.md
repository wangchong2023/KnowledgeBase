# 智宇 (KM) 国际化与本地化指南 (Localization Guide)

为了让 智宇 (KM) 走向全球，我们采用“双层本地化”架构。

## 1. 核心应用翻译 (App i18n)
*   **资产位置**: `Sources/Localization/Localizable.xcstrings` (String Catalog 格式)
*   **工作流**:
    1.  开发者在代码中使用 `Localized.tr("key")`。
    2.  翻译者在 `.strings` 文件中对应各语言。
    3.  **同步**: 运行 `python3 Tools/update_localization.py` 将各业务域的分表（如 `Graph.xcstrings`）词条同步到主表。
*   **规范**: 必须保留 `%@` 等占位符，且中文翻译需遵循《中文文案排版指引》。

## 2. 插件市场本地化 (Market i18n)
*   **策略**: 影子服务器支持 `Accept-Language` 请求头。
*   **JSON 结构**:
    ```json
    {
      "description": {
        "zh": "强大的插件...",
        "en": "Powerful plugin..."
      }
    }
    ```

## 3. 动态扩展
新增语言需在 `Localized.swift` 中注册对应的 Locale，确保日期格式与搜索分词器同步切换。`ThemeManager` 仅负责暗/亮色彩方案与主题色管理，不参与语言环境切换。
