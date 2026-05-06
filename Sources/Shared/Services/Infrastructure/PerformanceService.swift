// PerformanceService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的运行期性能监控与诊断服务（PerformanceService），旨在为系统的丝滑体验提供数据支撑。
// 该组件通过多维度的指标追踪与可视化看板，确保了系统的健壮性与响应效率，核心功能点如下：
// 1. 系统级资源监控：利用底层 Mach API 实时追踪应用的物理内存占用（MB），并提供周期性的自动刷新机制。
// 2. 核心操作耗时审计：内置精确的计时器闭包（measure），涵盖了数据库 CRUD、图谱布局算法及 FTS5 搜索等关键路径的延迟分析。
// 3. 知识资产画像：实时统计全库字数、页面规模及知识图谱的节点/边密度，为 RAG 索引与向量化提供量化的负载参考。
// 4. 交互式性能看板：提供直观的 PerformanceDashboard 视图，通过动态图表直观展示系统各环节的运行状态与响应水平。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化性能看板的 UI 间距与圆角常量
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import Foundation
#if canImport(MachO)
import MachO
#endif

// MARK: - Performance Service
/// Runtime performance monitoring and diagnostics for Knowledge Base.
@MainActor
final class PerformanceService: ObservableObject {
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring: Bool = false
    
    struct PerformanceMetrics: Identifiable {
        let id = UUID()
        var pageCount: Int = 0
        var totalWords: Int = 0
        var graphNodeCount: Int = 0
        var graphEdgeCount: Int = 0
        var memoryUsageMB: Double = 0
        var saveDuration: TimeInterval = 0
        var loadDuration: TimeInterval = 0
        var lintDuration: TimeInterval = 0
        var graphLayoutDuration: TimeInterval = 0
        var searchDuration: TimeInterval = 0
        var lastUpdated: Date = Date()
    }
    
    // MARK: - Timing Helpers
    func measure<T>(_ label: String, operation: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let duration = CFAbsoluteTimeGetCurrent() - start
        
        switch label {
        case "save": metrics.saveDuration = duration
        case "load": metrics.loadDuration = duration
        case "lint": metrics.lintDuration = duration
        case "graphLayout": metrics.graphLayoutDuration = duration
        case "search": metrics.searchDuration = duration
        default: break
        }
        metrics.lastUpdated = Date()
        return result
    }
    
    // MARK: - Memory
    func updateMemoryUsage() {
        // Use task_info via Mach API
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kernReturn: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kernReturn == KERN_SUCCESS {
            metrics.memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
    
    // MARK: - Page Metrics
    func updatePageMetrics(pages: [WikiPage]) {
        metrics.pageCount = pages.count
        metrics.totalWords = pages.reduce(0) { $0 + $1.wordCount }
        metrics.lastUpdated = Date()
    }
    
    // MARK: - Graph Metrics
    func updateGraphMetrics(nodes: Int, edges: Int) {
        metrics.graphNodeCount = nodes
        metrics.graphEdgeCount = edges
        metrics.lastUpdated = Date()
    }
    
    // MARK: - Summary
    var summary: String {
        """
        \(Localized.tr("perf.summary.title"))
        ━━━━━━━━━━━━━━━━━━━
        \(Localized.tr("perf.summary.pages")): \(metrics.pageCount) (\(metrics.totalWords) \(Localized.tr("perf.summary.words")))
        \(Localized.tr("perf.summary.graph")): \(metrics.graphNodeCount) \(Localized.tr("perf.summary.nodes")), \(metrics.graphEdgeCount) \(Localized.tr("perf.summary.edges"))
        \(Localized.tr("perf.summary.memory")): \(String(format: "%.1f", metrics.memoryUsageMB)) MB
        \(Localized.tr("perf.summary.save")): \(String(format: "%.3f", metrics.saveDuration))s
        \(Localized.tr("perf.summary.load")): \(String(format: "%.3f", metrics.loadDuration))s
        \(Localized.tr("perf.summary.lint")): \(String(format: "%.3f", metrics.lintDuration))s
        \(Localized.tr("perf.summary.graphLayout")): \(String(format: "%.3f", metrics.graphLayoutDuration))s
        \(Localized.tr("perf.summary.search")): \(String(format: "%.3f", metrics.searchDuration))s
        """
    }
}

// MARK: - Performance Dashboard View
struct PerformanceDashboardView: View {
    @ObservedObject var service: PerformanceService
    @Environment(\.dismiss) private var dismiss
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Memory
                    MetricCardView(
                        title: Localized.tr("perf.memory"),
                        value: String(format: "%.1f MB", service.metrics.memoryUsageMB),
                        icon: "memorychip",
                        color: .blue
                    )
                    
                    // Page Stats
                    HStack(spacing: 12) {
                        MetricCardView(
                            title: Localized.tr("perf.pages"),
                            value: "\(service.metrics.pageCount)",
                            icon: "doc.fill",
                            color: .green
                        )
                        MetricCardView(
                            title: Localized.tr("perf.words"),
                            value: "\(service.metrics.totalWords)",
                            icon: "textformat",
                            color: .purple
                        )
                    }
                    
                    // Graph Stats
                    HStack(spacing: 12) {
                        MetricCardView(
                            title: Localized.tr("perf.nodes"),
                            value: "\(service.metrics.graphNodeCount)",
                            icon: "circle.fill",
                            color: .orange
                        )
                        MetricCardView(
                            title: Localized.tr("perf.edges"),
                            value: "\(service.metrics.graphEdgeCount)",
                            icon: "line.diagonal",
                            color: .pink
                        )
                    }
                    
                    // Timing
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Localized.tr("perf.timing"))
                            .font(.headline)
                            .foregroundStyle(.wikiText)
                        
                        TimingRowView(label: Localized.tr("perf.save"), duration: service.metrics.saveDuration, color: .green)
                        TimingRowView(label: Localized.tr("perf.load"), duration: service.metrics.loadDuration, color: .blue)
                        TimingRowView(label: Localized.tr("perf.lint"), duration: service.metrics.lintDuration, color: .orange)
                        TimingRowView(label: Localized.tr("perf.graphLayout"), duration: service.metrics.graphLayoutDuration, color: .purple)
                        TimingRowView(label: Localized.tr("perf.search"), duration: service.metrics.searchDuration, color: .pink)
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                    
                    // Last Updated
                    Text(Localized.tr("perf.lastUpdated") + ": " + service.metrics.lastUpdated.formatted())
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding()
            }
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("perf.title"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        service.updateMemoryUsage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                service.updateMemoryUsage()
                timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak service] _ in
                    Task { @MainActor in
                        service?.updateMemoryUsage()
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

// MARK: - Metric Card
struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)
            Text(title)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
}

// MARK: - Timing Row
struct TimingRowView: View {
    let label: String
    let duration: TimeInterval
    let color: Color
    
    private var barWidth: CGFloat {
        let maxDuration: CGFloat = 1.0
        return min(CGFloat(duration) / maxDuration, 1.0) * 200
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: WikiUI.microRadius)
                    .fill(color.opacity(0.3))
                    .frame(width: geo.size.width, height: WikiUI.small)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: WikiUI.microRadius)
                            .fill(color)
                            .frame(width: max(barWidth, duration > 0 ? WikiUI.tiny : 0), height: WikiUI.small)
                    }
            }
            .frame(height: WikiUI.small)
            
            Text(String(format: "%.3fs", duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.wikiSecondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
