# 智元 (ZhiMind) 软件需求规格说明书 (SRS)

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

---
*本规范受架构 4+1 视图约束，是系统验收的最高技术依据。*
