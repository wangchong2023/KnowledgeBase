# 智宇 (ZhiYu) 性能基准报告 (Performance Benchmarks)

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

## 5. 50K 级大规模基准 (50K Page Benchmark)

针对 50,000+ 文档规模的极限性能验证框架：

| 指标维度 | 目标值 (50K Docs) | 观测工具 | 验证方法 |
| :--- | :--- | :--- | :--- |
| **内存峰值** | < 350MB | Instruments Allocations | 混合检索并发执行时采样 |
| **检索首字延迟** | < 800ms | `Signpost` 埋点 | 384 维向量余弦计算 + FTS5 召回全链路计时 |
| **冷启动速度** | < 800ms | `CFAbsoluteTime` | 节点索引预加载 + 主 UI 渲染完成 |
| **同步一致性** | 0 冲突分叉 | `KMiCloudSyncService` 日志 | 3 节点并发修改同一 UUID 页面，LWW 收敛验证 |
| **图谱流畅度** | 60 FPS | `CADisplayLink` | 节点拖拽与缩放操作期间帧率采样 |
| **数据库体积** | < 2GB | 文件系统 `stat` | 50K 页面含 FTS5 全文索引 + 向量嵌入总大小 |
| **导入吞吐** | > 200 pages/min | `IngestQueue` 背压计数 | 连续导入 1,000 个 10KB Markdown 文件 |

### 5.1 测试数据生成

```bash
# 使用脚本生成 50,000 篇合成 Markdown 文档
# 每篇包含 2-5 段随机文本、3-8 个 [[WikiLink]]、2-4 个标签
swift run -c release BenchmarkDataGenerator --count 50000 --output ./TestData/50k/
```

### 5.2 基准执行

| 阶段 | 操作 | 时长估计 | 关键监控项 |
| :--- | :--- | :--- | :--- |
| 1. 批量导入 | 导入 50K 文档到空库 | ~2h | `IngestQueue` 积压深度、CPU 持续占用 |
| 2. 稳态检索 | 随机 1,000 次混合检索 | ~30min | P50/P95/P99 延迟分布 |
| 3. 并发压力 | 3 模拟端同时写入 | ~1h | LWW 冲突率、最终收敛时间 |
| 4. 图谱渲染 | 50K 节点力导向布局 | ~15min | FPS 曲线、内存增长趋势 |
| 5. 长期浸泡 | 后台运行 24h | ~24h | 内存泄漏检测、电池消耗曲线 |

---
*注：以上数据为实验室内测值，实际表现受网络带宽及第三方 LLM 服务商延迟影响。*
