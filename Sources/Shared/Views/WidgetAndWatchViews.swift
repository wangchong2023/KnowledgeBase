// WidgetAndWatchViews.swift
//
// 作者: Wang Chong
// 功能说明: Lightweight view for Apple Watch showing key wiki stats and recent pages
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import WidgetKit

// MARK: - Apple Watch Quick View
/// Lightweight view for Apple Watch showing key wiki stats and recent pages
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
                        .stroke(Color.wikiAccent.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: min(1.0, Double(totalPages) / 100.0))
                        .stroke(Color.wikiAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(totalPages)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.wikiText)
                        Text(L10n.Widget.tr("pages"))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                
                // Word count
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text(formatNumber(totalWords))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.wikiText)
                        Text(L10n.Widget.tr("words"))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                
                Divider()
                
                // Recent pages
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.Widget.tr("recentUpdates"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.wikiSecondary)
                    
                    ForEach(recentTitles.prefix(5), id: \.self) { title in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.wikiAccent)
                                .frame(width: 5, height: 5)
                            Text(title)
                                .font(.caption2)
                                .foregroundStyle(.wikiText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(L10n.Widget.tr("title"))
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        let store = KMStore()
        store.loadFromDisk()
        totalPages = store.totalPages
        totalWords = store.totalWords
        recentTitles = store.pages
            .sorted { $0.updated > $1.updated }
            .prefix(5)
            .map { $0.title }
    }
    
    private func formatNumber(_ n: Int) -> String {
        if n >= 10000 {
            return String(format: "%.1f%@", Double(n) / 10000.0, L10n.Common.tr("unitTenThousand"))
        } else if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

// MARK: - Widget Preview Views (for development)
/// These views are designed for the Widget Extension target.
/// They read data directly from the shared JSON file.

struct KMWidgetPreview: View {
    let totalPages: Int
    let totalWords: Int
    let activeCount: Int
    let stubCount: Int
    let recentTitles: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "books.vertical.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.wikiAccent)
                Text(L10n.Widget.tr("title"))
                    .font(.caption.weight(.bold))
                Spacer()
                Text(Localized.trf("widget.pages", totalPages))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(totalWords)").font(.caption.weight(.bold))
                    Text(L10n.Widget.tr("characters")).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 2) {
                    Text("\(activeCount)").font(.caption.weight(.bold))
                    Text(L10n.Widget.tr("active")).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 2) {
                    Text("\(stubCount)").font(.caption.weight(.bold))
                    Text(L10n.Widget.tr("stub")).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            if !recentTitles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Widget.tr("recentUpdates"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    ForEach(recentTitles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Circle().fill(.purple).frame(width: 4, height: 4)
                            Text(title).font(.caption2).lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Widget Medium") {
    KMWidgetPreview(
        totalPages: 9,
        totalWords: 4500,
        activeCount: 7,
        stubCount: 2,
        recentTitles: ["LLM Wiki", "nanoGPT", L10n.Widget.tr("knowledgeCompile")]
    )
}
