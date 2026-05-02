# 智元 (ZhiMind) 性能基准报告 (Performance Benchmarks)

本报告基于真机（Apple Silicon / Neural Engine）实测数据，旨在为开发者提供系统级性能红线参考。

## 1. 测试环境 (Test Environment)
- **设备**: iPhone 15 Pro (A17 Pro) / Mac Studio (M2 Max)
- **系统**: iOS 17.5 / macOS 14.5
- **数据量**: 1,000 篇 Wiki 页面（平均每篇 2,500 字）

## 2. AI 与向量化性能 (NPU Metrics)

| 操作 | 吞吐量 (iPhone 15 Pro) | 吞吐量 (M2 Max) | 备注 |
| :--- | :--- | :--- | :--- |
| **语义分块** | 150 pages/sec | 400 pages/sec | 瓶颈在于正则解析 |
| **向量生成 (Embedding)** | 85 chunks/sec | 220 chunks/sec | 激活 Neural Engine (ANE) |
| **混合搜索 (Hybrid Search)** | < 120ms | < 45ms | 包含 FTS5 + Cosine Sim |
| **AI 智能编译 (LLM)** | ~25 tokens/sec | ~60 tokens/sec | 取决于 API 响应延迟 |

## 3. 存储与检索性能 (Storage Metrics)

| 指标 | 目标值 (Threshold) | 实测值 | 状态 |
| :--- | :--- | :--- | :--- |
| **冷启动时间** | < 1.2s | 0.9s | ✅ |
| **FTS5 全文搜索延迟** | < 100ms | 35ms | ✅ |
| **数据库 10k 条记录大小** | < 200MB | 145MB | ✅ |
| **主线程帧率 (UI FPS)** | > 58 FPS | 60 FPS | ✅ (GraphView 压力下) |

## 4. 电池与热耗 (Power & Thermal)
- **深度扫描模式**：在连续处理 500 篇文档时，设备有轻微发热，CPU 占用率控制在 35% 以内。
- **后台任务**：`BGTaskScheduler` 执行期间，能耗增量控制在每小时 2% 以下。

---
*注：以上数据为实验室内测值，实际表现受网络带宽及第三方 LLM 服务商延迟影响。*
