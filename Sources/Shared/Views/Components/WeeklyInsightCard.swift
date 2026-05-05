// WeeklyInsightCard.swift
//
// 作者: Wang Chong
// 功能说明: 知识周报卡片 (PM 视角：价值闭环)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 知识周报卡片 (PM 视角：价值闭环)
/// 知识周报卡片容器
/// 集成 AI 摘要与核心增长指标的可视化面板
struct WeeklyInsightCard: View {
    @Environment(KMStore.self) var store
    @Environment(AIWorkflowStore.self) var aiStore
    @Environment(AppRouter.self) var router
    @State private var isGenerating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                WikiGlow(icon: "sparkles", color: .purple, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Dashboard.tr("insight.weeklyTitle"))
                        .font(.title3.bold())
                        .foregroundStyle(.wikiText)
                    if let insight = aiStore.weeklyInsight {
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
            } else if let insight = aiStore.weeklyInsight {
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
                    .background(WikiUI.containerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
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
                                router.navigateToPage(id: page.id)
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
                                    .stroke(LinearGradient(colors: [WikiUI.containerBorder, .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: WikiUI.borderWidth)
                            )
                    }
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button(action: { generateInsight(forceRefresh: true) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Dashboard.tr("insight.generateReport"))
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
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth))
                    )
                    .foregroundStyle(.wikiAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            ZStack {
                WikiUI.containerBackground
                LinearGradient(colors: [.purple.opacity(0.05), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
        .onAppear {
            if aiStore.weeklyInsight == nil && !store.pages.isEmpty {
                generateInsight()
            }
        }
    }
    
    /**
     * @description: 触发周报生成任务，通过 AIWorkflowStore 调度分析逻辑
     * @param {Bool} forceRefresh 是否强制重新生成，忽略缓存
     * @return {*}
     */
    private func generateInsight(forceRefresh: Bool = false) {
        withAnimation { isGenerating = true }
        Task {
            await aiStore.generateWeeklyInsight(forceRefresh: forceRefresh)
            await MainActor.run {
                withAnimation { isGenerating = false }
            }
        }
    }
}

/// 周报指标项小组件
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

/// 知识周报详情全屏视图
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
                        Text(L10n.Dashboard.tr("insight.tips.title"))
                            .font(.headline)
                    }
                    
                    Text(L10n.Dashboard.tr("insight.tips.content"))
                        .font(.subheadline)
                        .lineSpacing(5)
                        .foregroundStyle(.wikiSecondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WikiUI.containerBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
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
