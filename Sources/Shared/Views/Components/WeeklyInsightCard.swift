import SwiftUI

/// 知识周报卡片 (PM 视角：价值闭环)
struct WeeklyInsightCard: View {
    @Environment(KMStore.self) var store
    @State private var isGenerating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                WikiGlow(icon: "sparkles", color: .purple, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localized.tr("insight.weeklyTitle"))
                        .font(.title3.bold())
                        .foregroundStyle(.wikiText)
                    if let insight = store.weeklyInsight {
                        Text(insight.dateRange)
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                Spacer()
                
                if isGenerating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(action: { generateInsight(forceRefresh: true) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                            .foregroundStyle(.wikiSecondary)
                            .padding(8)
                            .background(Circle().fill(Color.wikiBorder.opacity(0.2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isGenerating {
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBox(width: 200, height: 20)
                    SkeletonBox(width: 300, height: 16)
                    SkeletonBox(width: 260, height: 16)
                    SkeletonBox(width: 280, height: 16)
                }
            } else if let insight = store.weeklyInsight {
                VStack(alignment: .leading, spacing: 24) {
                    // 核心指标 (奖牌化设计)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 24) {
                            InsightStat(label: Localized.tr("stat.newPages"), value: "\(insight.totalNewPages)", icon: "doc.badge.plus", color: .blue)
                            Divider().frame(height: 36)
                            InsightStat(label: Localized.tr("stat.growth"), value: insight.growthTraction, icon: "chart.line.uptrend.xyaxis", color: .green)
                        }
                        
                        if !insight.topKeywords.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(insight.topKeywords, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.wikiAccent.opacity(0.1))
                                        .foregroundStyle(.wikiAccent)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.wikiCard.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
                    )

                    // 摘要正文
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "quote.opening")
                                .font(.title2)
                                .foregroundStyle(.wikiAccent.opacity(0.3))
                            Spacer()
                        }
                        
                        MarkdownRendererView(content: insight.aiSummary, isPrivate: false, onLinkTap: { title in
                            if let page = store.pages.first(where: { $0.title == title }) {
                                store.selectedPageID = page.id
                            }
                        })
                        .padding(.horizontal, 4)
                        
                        HStack {
                            Spacer()
                            Image(systemName: "quote.closing")
                                .font(.title2)
                                .foregroundStyle(.wikiAccent.opacity(0.3))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LinearGradient(colors: [Color.wikiAccent.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    }
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: { generateInsight(forceRefresh: true) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Localized.tr("insight.generateReport"))
                                .font(.headline)
                            Text(Localized.tr("weekly.aiAnalysis"))
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.title2)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.wikiAccent.opacity(0.15), .wikiAccent.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wikiAccent.opacity(0.3), lineWidth: 1))
                    )
                    .foregroundStyle(.wikiAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color.wikiCard
                LinearGradient(colors: [.purple.opacity(0.05), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
        .onAppear {
            if store.weeklyInsight == nil && !store.pages.isEmpty {
                generateInsight()
            }
        }
    }
    
    private func generateInsight(forceRefresh: Bool = false) {
        withAnimation { isGenerating = true }
        Task {
            await store.generateWeeklyInsight(forceRefresh: forceRefresh)
            await MainActor.run {
                withAnimation { isGenerating = false }
            }
        }
    }
}

struct InsightStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.wikiText)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
    }
}

struct WeeklyReportView: View {
    @Environment(KMStore.self) var store
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WeeklyInsightCard()
                
                // 深度建议
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                        Text(Localized.tr("insight.tips.title"))
                            .font(.headline)
                    }
                    
                    Text(Localized.tr("insight.tips.content"))
                        .font(.subheadline)
                        .lineSpacing(5)
                        .foregroundStyle(.wikiSecondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(.top, 10)
                
                // 底部占位，增加留白感
                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.weeklyInsight"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
