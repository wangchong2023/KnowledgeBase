# Knowledge Management 持续集成与发布工作流# 持续集成与交付 (CI/CD) 规范

## 1. 提交前检查 (Pre-commit)
开发者在 Push 代码前应在本地执行：
- `xcodebuild build`：确保 Swift 6 Strict Concurrency 模式下无 Error。
- `SwiftLint`：无严重风格告警。

## 2. 自动化流水线 (CI Pipeline)
每次 Pull Request 触发：
- **Build Audit**: 开启 `-Xfrontend -strict-concurrency=complete`。
- **Unit Testing**: 执行 `KMStoreTests`, `ServiceTests`。
- **UI Testing**: 执行 `KMUITests`（核心路径自动化）。
- **Performance Check**: 监控 `SearchIndexing` 耗时，若超过阈值则告警。

## 3. 发布标准
- **Crash Free Rate**: > 99.9%
- **Documentation**: 所有新增 Service 必须具备 L0-L3 分层说明。
- **Test Coverage**: 核心业务逻辑（Storage, AI, Search）覆盖率 > 80%。

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
