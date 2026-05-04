import SwiftUI

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
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.3))
                    .frame(width: geo.size.width, height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(barWidth, duration > 0 ? 4 : 0), height: 8)
                    }
            }
            .frame(height: 8)

            Text(String(format: "%.3fs", duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.wikiSecondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
