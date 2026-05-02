# Knowledge Management 测试与质量保证策略 (Test Strategy)

## 1. 测试原则 (QA Principles)
*   **左移测试**: 在开发阶段通过 XCTest 执行单元测试，而非依赖集成后的手动验证。
*   **数据驱动**: 针对 RAG 检索结果，使用标准语义评估集（Golden Set）进行打分回归。
*   **多端一致性**: 所有 UI 变更必须同时通过 iPhone (Compact) 与 iPad/Mac (Regular) 的布局校验。

## 2. 测试分层 (Test Layers)

### 2.1 单元测试 (Unit Tests) - P0
*   **核心 Service**: `LinkService`, `LLMService`, `IngestService`。
*   **目标**: 确保原子逻辑（如分块算法、RRF 打分、书签转换）的正确性。
*   **工具**: XCTest Framework。

### 2.2 集成测试 (Integration Tests) - P1
*   **RAG 管线**: 验证从 PDF 导入到向量召回的完整链路。
*   **持久化**: 验证 SQLite 与书签数据在 App 重启后的状态一致性。

### 2.3 UI 自动化测试 (UI Testing) - P1
*   **关键路径**: 
    - 唤起 `Cmd + K` 指令面板并执行跳转。
    - 页面编辑后的自动保存与撤销（Undo）。
    - 侧边栏在 iPad 上的展开/折叠状态。
*   **工具**: XCUITest。

## 3. 性能基准与极限吞吐量 (Performance & Stress Benchmarks)

针对 **50,000+** 级别文档规模，系统必须满足以下性能红线：

| 指标维度 | 目标值 (50K Docs) | 观测点/约束 |
| :--- | :--- | :--- |
| **内存峰值** | < 350MB | 混合检索并发执行时 (Instruments 监控) |
| **检索首字延迟** | < 800ms | 384 维向量余弦计算 + FTS5 召回 |
| **启动速度** | < 800ms | 节点索引预加载与主 UI 渲染 |
| **同步一致性** | 0 冲突分叉 | 并发 3 节点模拟测试 (基于 LWW 策略) |
| **流畅度** | 60 FPS | Graph 节点拖拽与缩放 |

## 4. 回归策略 (Regression Policy)
*   任何 `KMStore` 的状态变更逻辑修改，必须同步更新对应的单元测试用例。
*   主要版本发布前，需执行针对 iPad 分屏模式（Split View）的专项 UI 兼容性测试。
