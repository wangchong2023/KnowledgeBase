// WelcomeView.swift
//
// 作者: Wang Chong
// 功能说明: struct WelcomeView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Charts

struct WelcomeView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: AppTab
    @State private var showInjectSuccess = false
    @State private var injectedCount = 0
    
    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing: 32) {
                WelcomeHeroSection()
                WelcomeStatsSection()
                if !store.pages.isEmpty {
                    WelcomeGrowthChartSection(data: store.growthSeries)
                    WelcomeRecentUpdatesSection(selectedTab: $selectedTab)
                } else {
                    WelcomeQuickStartGuideSection(showInjectSuccess: $showInjectSuccess, injectedCount: $injectedCount)
                }
                WelcomeQuickActionsSection(selectedTab: $selectedTab)
            }
            .padding(.bottom, 40)
        }
        .background(Color.wikiBackground)
        .alert(L10n.Common.tr("success"), isPresented: $showInjectSuccess) {
            Button(L10n.Common.tr("awesome"), role: .cancel) { }
        } message: {
            Text(Localized.trf("settings.injectDemo.successMessage", injectedCount))
        }
    }
}

// MARK: - Sub-views

struct WelcomeHeroSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                WikiDotPattern(dotColor: .wikiBorder, spacing: 18, dotSize: 2).frame(width: 200, height: 100).opacity(0.5)
                Circle().fill(Color.wikiAccent.opacity(0.08)).frame(width: 140, height: 140).blur(radius: 20)
                Image(systemName: "books.vertical.circle.fill").font(.system(size: 72))
                    .foregroundStyle(LinearGradient(colors: [.wikiAccent, .wikiConcept], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .wikiAccent.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .frame(height: 100)
            Text(Localized.tr("page.wiki")).font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.wikiText)
            Text(Localized.tr("welcome.subtitle")).font(.subheadline).foregroundStyle(.wikiSecondary)
        }
        .padding(.top, 40)
    }
}

struct WelcomeStatsSection: View {
    @Environment(KMStore.self) var store
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: .infinity), spacing: 20)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            StatCard(title: Localized.tr("stat.totalPages"), value: "\(store.totalPages)", icon: "doc.richtext.fill", color: .wikiAccent)
            StatCard(title: Localized.tr("stat.entities"), value: "\(store.entityCount)", icon: "person.text.rectangle.fill", color: .wikiEntity)
            StatCard(title: Localized.tr("stat.concepts"), value: "\(store.conceptCount)", icon: "lightbulb.fill", color: .wikiConcept)
            StatCard(title: Localized.tr("stat.sources"), value: "\(store.sourceCount)", icon: "doc.plaintext.fill", color: .wikiSource)
        }
        .padding(.horizontal)
    }
}

struct WelcomeGrowthChartSection: View {
    let data: [KMStore.KnowledgeGrowthPoint]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.caption.weight(.semibold)).foregroundStyle(.wikiText)
                Text(Localized.tr("welcome.growthTrend")).font(.headline).foregroundStyle(.wikiText)
                Spacer()
            }
            Chart(data) { point in
                LineMark(x: .value("Date", point.date), y: .value("Count", point.count))
                    .foregroundStyle(.wikiAccent)
            }
            .frame(height: 120)
        }
        .padding(20).background(Color.wikiCard).clipShape(RoundedRectangle(cornerRadius: WikiUI.medium)).padding(.horizontal)
    }
}

struct WelcomeRecentUpdatesSection: View {
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    @Binding var selectedTab: AppTab
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").font(.caption.weight(.semibold)).foregroundStyle(.wikiText)
                Text(Localized.tr("recentUpdates")).font(.headline).foregroundStyle(.wikiText)
                Spacer()
            }.padding(.horizontal)
            ForEach(Array(store.pages.sorted { $0.updated > $1.updated }.prefix(5))) { page in
                Button(action: { router.navigateToPage(id: page.id) }) {
                    PageRowView(page: page, compact: true).padding(.horizontal)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct WelcomeQuickStartGuideSection: View {
    @Environment(KMStore.self) var store
    @Binding var showInjectSuccess: Bool
    @Binding var injectedCount: Int
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(.wikiText)
                Text(Localized.tr("welcome.quickStart")).font(.headline).foregroundStyle(.wikiText)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                GuideStepRow(number: 1, text: Localized.tr("welcome.guide.createPage"), icon: "doc.badge.plus")
                GuideStepRow(number: 2, text: Localized.tr("welcome.guide.wikiLink"), icon: "link")
            }
            
            // 快捷注入演示数据入口
            Button(action: {
                HapticManager.shared.trigger(.selection)
                injectedCount = store.generateDemoData()
                HapticManager.shared.trigger(.success)
                showInjectSuccess = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Localized.tr("welcome.demo.title"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.wikiAccent)
                        Text(Localized.tr("welcome.demo.desc"))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.wikiAccent)
                }
                .padding()
                .background(Color.wikiAccent.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.wikiAccent.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
        .padding(.horizontal)
    }
}

struct WelcomeQuickActionsSection: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: AppTab
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuickActionRow(icon: "plus.circle.fill", title: L10n.Action.tr("createPage"), subtitle: L10n.Action.tr("createPage.subtitle"), color: .wikiAccent) { store.showCreateSheet = true }
            QuickActionRow(icon: "tray.and.arrow.down.fill", title: L10n.Action.tr("ingestKnowledge"), subtitle: L10n.Action.tr("ingestKnowledge.subtitle"), color: .wikiSource) { selectedTab = .ingest }
        }.padding(.horizontal)
    }
}
