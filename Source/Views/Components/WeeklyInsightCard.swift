import SwiftUI

/// 知识周报卡片 (PM 视角：价值闭环)
struct WeeklyInsightCard: View {
    @EnvironmentObject var store: KMStore
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
                    Button(action: generateInsight) {
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
                VStack(alignment: .leading, spacing: 20) {
                    // 摘要正文 - 使用更好的排版
                    Text(insight.aiSummary)
                        .font(.callout)
                        .lineSpacing(6)
                        .foregroundStyle(.wikiText.opacity(0.95))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.wikiBackground.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    // 核心指标
                    HStack(spacing: 20) {
                        InsightStat(label: "新增页面", value: "\(insight.totalNewPages)", icon: "doc.badge.plus", color: .blue)
                        Divider().frame(height: 30)
                        InsightStat(label: "成长势能", value: insight.growthTraction, icon: "chart.line.uptrend.xyaxis", color: .green)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // 关键关键词标签
                    if !insight.topKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(Localized.tr("weekly.coreAreas"))
                                .font(.caption.bold())
                                .foregroundStyle(.wikiSecondary)
                            
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
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: generateInsight) {
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
    
    private func generateInsight() {
        withAnimation { isGenerating = true }
        Task {
            await store.generateWeeklyInsight()
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.wikiSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.wikiText)
            }
        }
    }
}

struct WeeklyReportView: View {
    @EnvironmentObject var store: KMStore
    
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
        .navigationBarTitleDisplayMode(.inline)
    }
}
