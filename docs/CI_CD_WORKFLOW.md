# Knowledge Management 持续集成与发布工作流 (CI/CD Workflow)

为了确保 Knowledge Management 在快速迭代中始终保持“工业级稳定性”，我们定义以下自动化流水线。

## 1. 提交流程 (PR Pipeline)
每当有代码合并请求时，必须通过以下自动化检查：

*   **L1: 静态检查 (Linting)**: 
    *   使用 `swiftlint` 检查代码规范与中文注释完备度。
*   **L2: 单元测试 (XCTest)**: 
    *   覆盖率必须 > 80%。核心算法（LWW, RAG 分块）必须 100% 通过。
*   **L3: 性能红线 (Benchmark Automation)**:
    *   自动运行 `PerformanceBenchmarker`。
    *   **硬指标**: 50,000 篇文档下，检索时延增量不得超过 5%。

## 2. 发布流程 (Release Pipeline)
*   **TestFlight 灰度**: 自动将 Beta 版本分发至“专家测试组”。
*   **插件兼容性扫描**: 自动扫描社区插件清单，标记可能受新版本内核影响的插件（基于 `minAppVersion`）。

## 3. 监控与回滚
*   **崩溃回传**: 利用 `LocalAnalyticsService` 收集的异常堆栈，当崩溃率超过 0.1% 时，自动触发版本回滚通知。
