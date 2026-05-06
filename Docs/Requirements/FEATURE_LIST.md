# 智宇 (ZhiYu) 全量特性与技术规格清单

> 本文档从 PRODUCT_REQUIREMENTS.md 中拆分，集中列出所有产品特性与技术规格。

---

## 1. 核心 AI 特性 (AI Core)
*   **多模型适配 (Adapter Pattern)**: 完美支持 OpenAI, DeepSeek, SiliconFlow 及本地 Ollama 引擎。
*   **智能编译 (Smart Ingest)**: 自动提取标签、摘要并重构 Markdown 内容。
*   **混合检索 (Hybrid RAG)**: 结合向量检索与关键词 RRF 算法，确保知识点精准召回。
*   **离线处理队列 (Ingest Queue)**: 后台异步处理大规模文档导入，不阻塞 UI。

## 2. 知识可视化 (Visualization)
*   **3D 动力学图谱**: 支持数万级节点的流畅渲染与物理布局。
*   **LOD 渲染优化**: 根据缩放级别自动调整节点细节，极致性能。
*   **语义聚类视图**: 自动将关联页面聚合为"领域星云"。

## 3. 跨端深度集成 (Platform Integration)
*   **iOS/iPadOS**:
    *   实时活动 (Live Activity) 监控 AI 进度。
    *   Apple Pencil 双击切换工具。
    *   Siri Shortcuts 快速记录。
*   **macOS**:
    *   Spotlight 全局系统搜索集成。
*   **watchOS (KMWatch)**:
    *   抬腕即记：支持系统级语音转文字采集。
    *   表盘秒开：通过 Complications 一键触发采集流程。
    *   离线同步：通过 WCSession 实现跨端无感数据对齐。

## 4. 安全与隐私 (Security)
*   **生物识别金库**: 支持 FaceID/TouchID 二次鉴权。
*   **隐私模式**: 支持一键模糊敏感内容。
*   **纯本地优先**: 数据存储于本地 SQLite，无强制云端同步。

## 5. 协作与生产力 (Collaboration & Productivity)
*   **实时协作**: 多用户协同编辑，冲突检测与合并。
*   **命令面板 (Cmd+K)**: 全局模糊搜索与快速指令执行。
*   **撤销/重做**: 全库操作历史，支持多级回退。

## 6. 知识维护与质量 (Maintenance & Quality)
*   **健康检查 (Lint)**: 检测断链、孤岛页面、循环引用、占位页面。
*   **勋章/游戏化**: 知识贡献勋章墙（稀有度系统、解锁动画）。
*   **操作日志 (Activity)**: 记录创建、更新、删除、编译等所有关键行为。

## 7. 多模态采集 (Multi-Modal Ingest)
*   **OCR 扫描**: Vision 框架高精度文字识别。
*   **语音笔记**: 10+ 语言实时转写。
*   **PDF 解析**: 原生 PDF 阅读与结构化提取。
*   **PPTX 导出**: 将 AI 合成结果导出为 PowerPoint 演示文稿。

## 8. 空间计算 (Spatial Computing)
*   **Vision Pro 空间视图**: 在现实空间中展开知识图谱，沉浸式交互。

## 9. 软件规格 (Specifications)
*   **存储引擎**: SQLite 3.35.0+。
*   **向量引擎**: 基于 Accelerate 框架的余弦相似度计算。
*   **UI 框架**: SwiftUI (100% 原生)。
*   **最低支持**: iOS 17.0+, macOS 14.0+, watchOS 10.0+。
