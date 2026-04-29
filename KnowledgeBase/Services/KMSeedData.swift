import Foundation

// MARK: - KM Seed Data
/// Default wiki pages pre-populated on first launch.
/// Structured as static data to keep SQLiteStore clean.
struct KMSeedData {

    /// All default pages to seed.
    static let pages: [(title: String, type: PageType, content: String, tags: [String])] = [
        // === Entities ===
        (
            title: "Andrej Karpathy",
            type: .entity,
            content: """
            # Andrej Karpathy

            AI 研究者，前 OpenAI 创始成员、前 Tesla AI 总监。

            ## 核心贡献
            - 提出 [[LLM Wiki]] 知识管理范式
            - 创建 [[nanoGPT]] 和 [[llm.c]] 开源项目
            - Stanford CS231n 深度学习课程主讲人

            ## 关键理念
            - 编译而非检索：知识应该被"编译"一次，持续使用
            - Obsidian 是 IDE，Wiki 是代码库，LLM 是程序员
            - 中等规模知识库无需向量数据库，靠 Markdown 索引即可

            ## 相关链接
            - [[LLM Wiki]]
            - [[RAG]]
            - [[知识编译]]
            """,
            tags: ["AI", "研究者", "OpenAI", "Tesla"]
        ),

        // === Concepts ===
        (
            title: "LLM Wiki",
            type: .concept,
            content: """
            # LLM Wiki

            Karpathy 提出的个人知识管理范式，核心思想是让 LLM 主动维护一个持久的结构化 Wiki。

            ## 核心架构

            ```
            ┌─────────────────────┐
            │  Schema (CLAUDE.md) │  ← 规则配置
            ├─────────────────────┤
            │  Wiki (wiki/)       │  ← LLM 生成的结构化 Markdown
            ├─────────────────────┤
            │  Raw (raw/)         │  ← 原始资料（只读）
            └─────────────────────┘
            ```

            ## 四大操作

            | 操作 | 说明 |
            |------|------|
            | Import | 知识导入：将 raw/ 内容编译到 wiki |
            | Query | 智能查询：基于编译后的知识回答问题 |
            | Lint | 健康检查：检测矛盾、断链、孤立页面 |
            | Fix | 修复：逐条审批 Lint 报告 |

            ## 与 [[RAG]] 的对比

            | 维度 | 传统 RAG | LLM Wiki |
            |------|----------|----------|
            | 知识处理 | 被动检索 | 主动编译 |
            | 生命周期 | 临时性 | 持久化 |
            | 维护 | 无 | LLM 全职维护 |

            ## 核心优势
            - 🔄 知识复利累积
            - 🤖 零维护负担
            - 🏗️ 中等规模免基建（~100篇/40万字）
            - ⚡ 使用即增长飞轮

            ## 相关链接
            - [[Andrej Karpathy]]
            - [[RAG]]
            - [[知识编译]]
            - [[双向链接]]
            """,
            tags: ["知识管理", "AI", "LLM", "方法论"]
        ),

        (
            title: "RAG",
            type: .concept,
            content: """
            # RAG（检索增强生成）

            Retrieval-Augmented Generation，一种将检索与生成结合的 AI 架构模式。

            ## 工作流程
            1. 用户提出查询
            2. 从向量数据库检索相关文档片段
            3. 将检索结果作为上下文喂给 LLM
            4. LLM 基于上下文生成回答

            ## 局限性
            - 每次查询从零检索，知识"用完即弃"
            - 检索质量依赖向量嵌入的精度
            - 缺乏知识间的交叉引用
            - 无法检测知识间的矛盾

            ## 替代方案
            [[LLM Wiki]] 提出了"编译而非检索"的范式转换，让知识持久累积。

            ## 相关链接
            - [[LLM Wiki]]
            - [[知识编译]]
            - [[向量数据库]]
            """,
            tags: ["AI", "检索", "RAG", "架构"]
        ),

        (
            title: "知识编译",
            type: .concept,
            content: """
            # 知识编译

            LLM Wiki 的核心隐喻：将原始资料"编译"为结构化知识，类似编译器将源代码编译为可执行程序。

            ## 编译器映射

            | 编译器概念 | LLM Wiki 对应 |
            |------------|---------------|
            | 源代码 | raw/ 目录中的原始文档 |
            | 编译产物 | wiki/ 目录中的 Markdown |
            | 编译器 | LLM |
            | 构建配置 | Schema (CLAUDE.md) |
            | 增量编译 | 新文档摄入只更新受影响页面 |
            | 依赖图 | 交叉引用和反向链接 |
            | Lint | Wiki 健康检查 |

            ## 关键特性
            - 知识编译一次，持续保鲜
            - 交叉引用持久化
            - 矛盾自动标注
            - 越用越厚

            ## 相关链接
            - [[LLM Wiki]]
            - [[Andrej Karpathy]]
            - [[双向链接]]
            """,
            tags: ["知识管理", "编译", "方法论"]
        ),

        (
            title: "双向链接",
            type: .concept,
            content: """
            # 双向链接

            知识管理的核心机制，允许页面之间建立双向关联。当页面 A 链接到页面 B 时，B 自动感知来自 A 的引用。

            ## 语法
            使用 `[[页面标题]]` 语法创建链接：
            - `[[LLM Wiki]]` → 链接到 LLM Wiki 页面
            - `[[RAG|RAG 检索]]` → 带别名的链接

            ## 优势
            - 🔗 发现隐含关联
            - 🕸️ 构建知识网络
            - 📊 支持图谱可视化
            - 🔍 反向链接提供上下文

            ## 在知识库中的实现
            - 编辑器中自动识别 `[[...]]` 语法
            - 支持点击跳转
            - 反向链接面板显示所有引用当前页面的页面

            ## 相关链接
            - [[LLM Wiki]]
            - [[知识编译]]
            - [[知识图谱]]
            """,
            tags: ["链接", "知识管理", "Obsidian"]
        ),

        (
            title: "知识图谱",
            type: .concept,
            content: """
            # 知识图谱

            将 Wiki 中的页面及其关联关系可视化为网络图，是 Obsidian 和知识库的核心视图之一。

            ## 图谱特征
            - **节点**：每个 Wiki 页面是一个节点
            - **边**：页面间的 `[[wikilink]]` 构成边
            - **颜色**：按页面类型着色
            - **大小**：按链接数量决定节点大小

            ## 布局算法
            - 力导向布局（Force-Directed Layout）
            - 节点间引力与斥力平衡
            - 连接紧密的节点聚集在一起

            ## 用途
            - 发现知识盲区
            - 识别孤立页面
            - 理解知识结构
            - 导航探索

            ## 相关链接
            - [[双向链接]]
            - [[LLM Wiki]]
            """,
            tags: ["可视化", "图谱", "知识管理"]
        ),

        (
            title: "nanoGPT",
            type: .entity,
            content: """
            # nanoGPT

            Karpathy 创建的最简 GPT 训练框架，旨在用最简单、最快的方式训练/微调中型 GPT 模型。

            ## 特点
            - 极简代码，易于理解
            - 支持 GPT-2/GPT-3 架构
            - 训练和微调一体化
            - 适合教学和实验

            ## 相关链接
            - [[Andrej Karpathy]]
            - [[llm.c]]
            """,
            tags: ["开源", "GPT", "训练"]
        ),

        (
            title: "llm.c",
            type: .entity,
            content: """
            # llm.c

            Karpathy 创建的用纯 C/CUDA 训练 LLM 的项目，无需庞大的 Python 依赖。

            ## 特点
            - 纯 C/CUDA 实现
            - 极致性能
            - 最小化依赖
            - 教育目的为主

            ## 相关链接
            - [[Andrej Karpathy]]
            - [[nanoGPT]]
            """,
            tags: ["开源", "C", "CUDA", "训练"]
        ),

        (
            title: "向量数据库",
            type: .concept,
            content: """
            # 向量数据库

            专门用于存储和检索向量嵌入的数据库系统，是传统 [[RAG]] 架构的核心组件。

            ## 代表产品
            - Pinecone
            - Weaviate
            - Milvus
            - Chroma

            ## 在 LLM Wiki 中的定位
            LLM Wiki 认为在中等规模（~100篇/40万字）下，无需向量数据库，仅靠 Markdown 索引文件即可高效检索。

            ## 相关链接
            - [[RAG]]
            - [[LLM Wiki]]
            """,
            tags: ["数据库", "向量", "检索"]
        ),

        (
            title: "Obsidian",
            type: .entity,
            content: """
            # Obsidian

            本地化知识管理工具，基于 Markdown 文件的双向链接笔记系统。在 LLM Wiki 范式中充当"IDE"角色。

            ## 核心特性
            - 本地存储，数据完全自有
            - [[双向链接]] 与反向链接
            - 知识图谱可视化
            - 丰富的插件生态

            ## 推荐插件
            - Obsidian Web Clipper：一键网页 → Markdown
            - Dataview：动态查询
            - Local Images Plus：图片本地化
            - Marp：生成演示文稿

            ## 相关链接
            - [[LLM Wiki]]
            - [[双向链接]]
            - [[知识图谱]]
            """,
            tags: ["工具", "笔记", "知识管理", "Markdown"]
        ),
    ]
}
