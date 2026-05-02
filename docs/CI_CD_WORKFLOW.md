# Knowledge Management 持续集成与发布工作流 (CI/CD Workflow)

为了确保 Knowledge Management 在快速迭代中始终保持“工业级稳定性”，我们定义以下自动化流水线。

## 1. 提交流程 (PR Pipeline)
每当有代码合并请求时，必须通过以下自动化检查：

*   **L1: 静态检查 (Linting)**: 
    *   使用 `swiftlint --strict` 强制执行代码规范。任何警告都将被视为错误并阻断构建。
*   **L2: 单元测试 (XCTest)**: 
    *   全库代码覆盖率阈值强制设定为 **85%**。
    *   核心算法（LWW-Element-Set, RAG 分块, 向量相似度计算）必须 100% 通过。
*   **L3: 性能红线 (Benchmark Automation)**:
    *   自动对比 `Docs/Testing/PERFORMANCE_BENCHMARK.md` 中的基准数据。
    *   **硬指标**: 在 1,000 篇基准文档下，检索时延增量不得超过 5%。

## 2. 发布流程 (Release Pipeline)
*   **TestFlight 灰度**: 自动将 Beta 版本分发至“专家测试组”。
*   **插件兼容性扫描**: 自动扫描社区插件清单，标记可能受新版本内核影响的插件（基于 `minAppVersion`）。

## 3. 监控与回滚
*   **崩溃回传**: 利用 `LocalAnalyticsService` 收集的异常堆栈，当崩溃率超过 0.1% 时，自动触发版本回滚通知。
