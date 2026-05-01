import SwiftUI

/// 知识周报卡片 (PM 视角：价值闭环)
struct WeeklyInsightCard: View {
    @EnvironmentObject var store: KMStore
    @State private var isGenerating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                WikiGlow(icon: "sparkles", color: .purple, size: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("本周知识洞察")
                        .font(.headline)
                    if let insight = store.weeklyInsight {
                        Text(insight.dateRange)
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                Spacer()
                
                Button(action: generateInsight) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                        .foregroundStyle(.wikiSecondary)
                }
                .buttonStyle(.plain)
            }
            
            if isGenerating {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBox(width: 200, height: 16)
                    SkeletonBox(width: 280, height: 12)
                    SkeletonBox(width: 240, height: 12)
                }
            } else if let insight = store.weeklyInsight {
                VStack(alignment: .leading, spacing: 12) {
                    Text(insight.aiSummary)
                        .font(.subheadline)
                        .lineSpacing(4)
                        .foregroundStyle(.wikiText.opacity(0.9))
                    
                    HStack(spacing: 12) {
                        InsightStat(label: "新增知识", value: "\(insight.totalNewPages)", color: .blue)
                        InsightStat(label: "成长状态", value: insight.growthTraction, color: .green)
                        Spacer()
                        
                        HStack(spacing: 4) {
                            ForEach(insight.topKeywords, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: generateInsight) {
                    HStack {
                        Text("点击生成个人智库周报")
                            .font(.subheadline.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.wikiAccent.opacity(0.1))
                    .foregroundStyle(.wikiAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.wikiCard
                LinearGradient(colors: [.purple.opacity(0.05), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
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
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.wikiSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}
