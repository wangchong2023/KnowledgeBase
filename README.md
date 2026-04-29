# WikiCraft 📚

> 基于 Karpathy LLM Wiki 方法论的 iOS 知识管理应用

## 灵感来源

WikiCraft 的核心理念来自 [Andrej Karpathy](https://twitter.com/karpathy) 提出的 **LLM Wiki** 个人知识管理范式：

> **编译而非检索** —— 让知识被"编译"一次，持续使用，而非每次查询都从零拼凑。

核心隐喻：
- **Obsidian = IDE** — 阅读、浏览、可视化
- **Wiki = 代码库** — 持久化的结构化知识
- **LLM = 程序员** — 全职维护知识库

## 功能特性

### 🔗 双向链接 (Bidirectional Links)
- 使用 `[[页面标题]]` 语法创建链接
- 自动检测反向链接
- 支持点击跳转导航
- 反向链接面板展示所有引用
- Wikilink Picker 页面选择器

### 🕸️ 知识图谱 (Knowledge Graph)
- 力导向布局算法（模拟退火优化）
- 按页面类型着色 + 类型筛选
- 节点大小反映链接数量
- 点击节点查看详情并跳转
- 选中节点脉冲动画 + 边高亮
- 捏合缩放 + 拖拽平移 + 重置
- 图例面板
- 一键重新布局

### 🤖 LLM AI 助手
- 支持多种 LLM 服务商（OpenAI / DeepSeek / 自定义 API）
- 流式 Chat 对话（SSE streaming）
- Wiki 感知：自动注入知识库内容作为上下文
- [[wikilink]] 可点击跳转到相关页面
- 相关页面 chips 展示
- 智能灌入（Smart Ingest）：LLM 自动编译原始资料
- 编译预览：内容/类型/标签/关联页面/摘要
- 连接测试与 API Key 验证

### 📥 知识灌入 (Ingest)
- 粘贴原始内容一键编译到 Wiki
- 自动检测已有页面的交叉引用
- 支持 Markdown 格式
- 自动更新索引和日志

### 📤 导入/导出
- 导出为 Markdown（ShareLink）
- 从剪贴板导入（JSON 或 Markdown 格式）
- 自动去重（已存在标题的页面跳过）

### 🔍 智能搜索
- 全文搜索（标题、内容、标签、别名）
- 按类型、状态筛选
- 多种排序方式
- 快速过滤标签

### 🩺 健康检查 (Lint)
- 断链检测：引用了不存在的页面
- 孤立页面：没有任何反向链接
- 占位内容：内容少于100字
- 过时检测：超过30天未更新
- 提供修复建议

### 🏷️ 页面类型系统
| 类型 | 说明 | 颜色 |
|------|------|------|
| 实体 (Entity) | 人物、公司、工具 | 🔵 蓝色 |
| 概念 (Concept) | 理论、框架、方法论 | 🟣 紫色 |
| 来源 (Source) | 每个摄入来源一个页面 | 🟢 绿色 |
| 对比 (Comparison) | 对比分析 | 🟠 橙色 |
| 地图 (Map) | 主题导航页 | 🔴 红色 |

### 📊 页面元数据
- **状态**: 活跃 / 占位 / 待更新 / 已弃用
- **可信度**: 高 / 中 / 低
- **Frontmatter**: 标签、别名、来源、关联页面
- **收藏**: 置顶重要页面
- **统计**: 字数、创建/更新时间、出链数

### 🤖 LLM AI 助手
- **Chat 对话**：Wiki 感知，自动注入相关上下文
- **流式输出**：SSE streaming 实时显示
- **Wikilink 交互**：回复中的 `[[页面]]` 可点击跳转
- **智能灌入**：LLM 自动编译原始资料 → 结构化 Wiki
- 支持 OpenAI / DeepSeek / 自定义 API

### ☁️ iCloud 同步
- CloudKit 私有数据库存储
- 双向同步（上传/下载/合并）
- 冲突检测与解决（合并/保留本地/保留远程）
- 自动同步开关
- 同步状态实时显示

### 📄 PDF 阅读与标注
- 导入 PDF 文档到文档库
- 全文阅读 + 翻页浏览
- 高亮标注（5 种颜色 + 备注）
- 灌入到知识库（全文/页范围/仅标注）
- 文档管理（删除/滑动操作）

### 📷 OCR 文字识别
- Vision 框架中文/英文/日文/韩文识别
- 从相册选择图片识别
- 识别结果一键灌入知识库
- 自定义页面类型和标签

### 🎤 Siri 快捷指令
- "搜索知识库" — 语音搜索
- "创建知识页面" — 语音创建
- "知识库统计" — 语音查询统计

### 📱 Widget 小组件
- 小组件：页面数量概览
- 中组件：统计 + 最近更新列表
- 4 小时自动刷新

### ⌚ Apple Watch
- 知识库统计环形进度
- 字数/活跃页面/占位页面
- 最近更新列表

### 🎨 主题
- 亮色/暗色模式自适应
- 多种主题色可选（8 种）
- 自适应配色方案（所有颜色适配 light/dark）
- 自定义主题色

### 🧑‍🤝‍🧑 实时协作
- MultipeerConnectivity 局域网协作（Wi-Fi / 蓝牙）
- 主持/加入协作房间
- 实时编辑同步与广播
- 角色管理：主持人 / 编辑者 / 查看者
- 端到端加密传输
- 编辑历史追踪

### 🌐 3D 知识图谱
- SceneKit 3D 可视化
- Fibonacci 球面分布布局
- 按页面类型着色的 3D 节点
- 自动旋转 + 手势控制相机
- 类型筛选 + 节点信息面板
- 网格地面 + 边连接线

### 🎤 语音笔记
- Apple Speech 框架实时语音转文字
- 10+ 种语言支持（中/英/日/韩/法/德/西/葡等）
- 实时音频电平可视化
- 一键保存转录到知识库
- 录音历史管理
- 音频文件转录支持

### 🥽 空间计算（Vision Pro）
- visionOS 沉浸式 3D 知识图谱
- RealityKit 实体交互
- 手势 + 眼动追踪选择节点
- iOS 预览模式（视差 3D 效果）
- 空间音频反馈

### ⚡ 端侧 LLM（Core ML）
- Core ML 模型本地推理
- 支持 Apple Intelligence（iOS 18.2+）
- 导入自定义 .mlmodelc 模型
- 端侧 Chat + 智能灌入
- Neural Engine 加速
- 完全离线 + 隐私安全
- 推理速度监测

### ↩️ 撤销 / 重做
- 快照式撤销/重做系统（最多 50 步）
- 工具栏一键撤销/重做
- 创建/更新/删除/灌入全操作支持

### 💾 备份与恢复
- 自动备份（5 分钟间隔，最多保留 20 份）
- 手动创建备份
- 从备份恢复（恢复前自动安全备份）
- 崩溃恢复检测（dirty flag 机制）
- 备份文件大小/页面数/字数统计

### 🔗 深度链接 + Spotlight
- URL Scheme `wikicraft://` 深度链接
- 支持 page/search/ingest/graph/chat 路由
- CoreSpotlight 索引：页面可从系统搜索打开
- NSUserActivity 集成

### ♿ 无障碍
- VoiceOver 完整支持（页面/图谱/导航）
- 动态字体缩放适配
- 减弱动态效果自动检测
- 触觉反馈（Haptic）
- 高对比度模式适配

### 📊 性能监控
- 运行时内存使用监测
- 保存/加载/Lint/搜索/图谱布局耗时
- 图谱节点/边数统计
- 实时性能仪表板

## 项目结构

```
WikiCraft/
├── WikiCraft.xcodeproj/
│   └── project.pbxproj
├── project.yml                     # XcodeGen 配置
└── WikiCraft/
    ├── WikiCraftApp.swift          # App 入口
    ├── ContentView.swift           # 主界面 + 欢迎页
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/
    │   └── Models.swift            # 数据模型（含 CJK 字数统计）
    ├── Services/
    │   ├── WikiStore.swift         # 核心数据存储门面
    │   ├── PageStore.swift         # CRUD + 持久化 + 种子数据
    │   ├── LLMService.swift        # LLM API 集成（Chat/Smart Ingest）
    │   ├── iCloudSyncService.swift  # iCloud CloudKit 同步
    │   ├── PDFService.swift        # PDF 文档管理 + 文本提取
    │   ├── OCRService.swift        # Vision OCR 文字识别
    │   ├── SpeechService.swift     # Speech 框架语音转文字
    │   ├── CollaborationService.swift # MultipeerConnectivity 实时协作
    │   ├── OnDeviceLLMService.swift # Core ML 端侧 LLM 推理
    │   ├── UndoService.swift       # 撤销/重做快照系统
    │   ├── BackupService.swift     # 自动备份 + 崩溃恢复
    │   ├── DeepLinkService.swift   # 深度链接 + Spotlight 索引
    │   ├── AccessibilityService.swift # VoiceOver + 动态字体 + 触觉
    │   ├── PerformanceService.swift # 性能监控 + 耗时统计
    │   ├── ShortcutsService.swift  # Siri 快捷指令
    │   ├── LinkService.swift       # 链接解析 + 搜索
    │   ├── LintService.swift       # 健康检查
    │   ├── IngestService.swift     # 知识灌入
    │   └── LogService.swift        # 操作日志
    ├── Utilities/
    │   └── ThemeManager.swift      # 主题管理 + 自适应颜色系统
    └── Views/
        ├── SidebarView.swift       # 侧边栏导航（含收藏区）
        ├── PageDetailView.swift    # 页面详情（面包屑 + 别名 + 收藏）
        ├── MarkdownEditorView.swift # Markdown 编辑器（标签+别名编辑）
        ├── MarkdownRendererView.swift # Markdown 渲染器
        ├── GraphView.swift         # 知识图谱可视化（动画+筛选）
        ├── Graph3DView.swift       # 3D 知识图谱（SceneKit）
        ├── ChatView.swift          # AI 助手聊天界面
        ├── LLMSettingsView.swift   # LLM 设置页
        ├── OnDeviceLLMSettingsView.swift # 端侧 LLM 设置 + 测试
        ├── CollaborationView.swift # 实时协作界面
        ├── VoiceNoteView.swift     # 语音笔记界面
        ├── VisionProSpatialView.swift # 空间计算 Vision Pro 视图
        ├── BackupView.swift        # 备份与恢复界面
        ├── PerformanceDashboardView.swift # 性能仪表板（含在 PerformanceService.swift 中）
        ├── iCloudSyncView.swift    # iCloud 同步设置页
        ├── PDFReaderView.swift     # PDF 阅读器 + 高亮标注
        ├── PDFLibraryView          # （含在 PDFReaderView 中）
        ├── OCRScanView.swift       # OCR 文字识别扫描页
        ├── WidgetAndWatchViews.swift # Widget + Watch 视图
        ├── SearchView.swift        # 搜索与筛选
        ├── IndexView.swift         # 总索引
        ├── LogView.swift           # 操作日志
        ├── BacklinksView.swift     # 反向链接
        ├── TagCloudView.swift      # 标签云
        ├── IngestView.swift        # 知识灌入（含智能灌入 + OCR 入口）
        ├── LintView.swift          # 健康检查
        ├── SettingsView.swift      # 设置（含 LLM + iCloud + 端侧入口）
        └── CreatePageView.swift    # 创建页面
```

## 技术栈

- **SwiftUI** — 声明式 UI 框架
- **iOS 17+** — 目标平台
- **Documents 目录 JSON 文件** — 本地数据持久化
- **CloudKit** — iCloud 同步
- **Vision** — OCR 文字识别
- **Speech** — 语音转文字
- **PDFKit** — PDF 阅读与标注
- **Core ML** — 端侧 LLM 推理
- **SceneKit** — 3D 知识图谱
- **MultipeerConnectivity** — 局域网实时协作
- **RealityKit** — 空间计算（visionOS）
- **AppIntents** — Siri 快捷指令
- **WidgetKit** — 主屏幕小组件
- **Canvas API** — 知识图谱绘制
- **FlowLayout** — 自定义标签云布局
- **NavigationSplitView** — iPad 适配
- **Adaptive Colors** — 亮色/暗色自适应配色
- **CoreSpotlight** — 系统级搜索索引
- **NSUserActivity** — 手-off 与深度链接
- **XCTest** — 单元测试覆盖

## 快速开始

### 方式一：Xcode 直接打开
1. 打开 `WikiCraft.xcodeproj`
2. 选择模拟器或真机
3. 点击 Run (⌘R)

### 方式二：XcodeGen 生成（推荐）
1. 安装 XcodeGen: `brew install xcodegen`
2. 在项目根目录运行: `xcodegen generate`
3. 打开生成的 `.xcodeproj`

## Karpathy LLM Wiki 核心架构

```
┌─────────────────────────────────┐
│  Schema 层 (CLAUDE.md)          │  ← 规则配置
├─────────────────────────────────┤
│  Wiki 层 (wiki/)                │  ← LLM 生成的结构化 Markdown
├─────────────────────────────────┤
│  Raw 层 (raw/)                  │  ← 原始资料（只读）
└─────────────────────────────────┘
```

### 四大核心操作
| 操作 | 说明 |
|------|------|
| **Ingest** | 知识灌入：将原始资料编译到 Wiki |
| **Query** | 智能查询：基于编译后的知识回答问题 |
| **Lint** | 健康检查：检测矛盾、断链、孤立页面 |
| **Fix** | 修复：逐条审批 Lint 报告 |

### vs 传统 RAG
| 维度 | 传统 RAG | LLM Wiki |
|------|----------|----------|
| 知识处理 | 被动检索 | 主动编译 |
| 生命周期 | 临时性 | 持久化 |
| 维护 | 无 | LLM 全职维护 |
| 交叉引用 | 无 | 双向链接 |
| 矛盾检测 | 无 | 自动标注 |

## 预置知识库

App 内置了 Karpathy LLM Wiki 方法论相关的预置内容：

- **实体**: Andrej Karpathy, nanoGPT, llm.c, Obsidian
- **概念**: LLM Wiki, RAG, 知识编译, 双向链接, 知识图谱, 向量数据库

每个页面之间通过 `[[wikilink]]` 建立关联，启动即可体验完整的知识网络。

## 后续规划

- [x] LLM API 集成（自动编译）✅
- [x] iCloud 同步 ✅
- [x] PDF 阅读与标注 ✅
- [x] OCR 文字识别 ✅
- [x] Siri 快捷指令 ✅
- [x] Widget 小组件 ✅
- [x] Apple Watch 快速查看 ✅
- [x] 实时协作（多用户编辑）✅
- [x] 知识图谱 3D 可视化 ✅
- [x] 语音笔记转文字 ✅
- [x] 空间计算（Vision Pro）✅
- [x] 端侧 LLM（Core ML）✅
- [x] 撤销 / 重做 ✅
- [x] 备份与恢复 ✅
- [x] 深度链接 + Spotlight 索引 ✅
- [x] 无障碍（VoiceOver + 动态字体）✅
- [x] 性能监控 Dashboard ✅
- [x] 单元测试覆盖 ✅

## License

MIT License

---

> *"人类的工作是策展来源、引导分析、问好问题。LLM 的工作是除此之外的一切。"*  
> — Andrej Karpathy
