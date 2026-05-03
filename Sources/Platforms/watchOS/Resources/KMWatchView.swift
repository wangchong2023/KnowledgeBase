import SwiftUI

// MARK: - Watch-specific Colors
private extension Color {
    static let watchAccent = Color.blue
    static let watchText = Color.primary
    static let watchSecondary = Color.secondary
}

// MARK: - Apple Watch Quick View
/// Apple Watch 简易视图，展示知识库关键统计和最近页面
struct WatchWikiStatsView: View {
    @State private var totalPages = 0
    @State private var totalWords = 0
    @State private var recentTitles: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Stats circle
                ZStack {
                    Circle()
                        .stroke(Color.watchAccent.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, Double(totalPages) / 100.0))
                        .stroke(Color.watchAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(totalPages)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.watchText)
                        Text(L.tr("watch.pages"))
                            .font(.caption2)
                            .foregroundStyle(Color.watchSecondary)
                    }
                }
                
                // Word count
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text(formatNumber(totalWords))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.watchText)
                        Text(L.tr("watch.words"))
                            .font(.caption2)
                            .foregroundStyle(Color.watchSecondary)
                    }
                }
                
                Divider()
                
                // Recent pages
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.tr("watch.recentUpdates"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.watchSecondary)
                    
                    ForEach(recentTitles.prefix(5), id: \.self) { title in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.watchAccent)
                                .frame(width: 5, height: 5)
                            Text(title)
                                .font(.caption2)
                                .foregroundStyle(Color.watchText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("KM")
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        totalPages = defaults.integer(forKey: "watch_totalPages")
        totalWords = defaults.integer(forKey: "watch_totalWords")
        recentTitles = defaults.stringArray(forKey: "watch_recentTitles") ?? []
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.1f" + L.tr("watch.tenThousand"), Double(n) / 10000.0)
        } else if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

// MARK: - Watch L (minimal localization for watchOS target)
private enum L {
    static func tr(_ key: String) -> String {
        let table: [String: String] = [
            "watch.pages": "页面",
            "watch.words": "字",
            "watch.recentUpdates": "最近更新",
            "watch.tenThousand": "万",
        ]
        return table[key] ?? key
    }
}
