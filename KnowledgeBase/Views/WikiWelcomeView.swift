import SwiftUI

// MARK: - Welcome View
struct WikiWelcomeView: View {
    @EnvironmentObject var store: KMStore
    @Binding var selectedTab: ContentView.AppTab
    @State private var showCreateSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero — 带点阵背景 + 光晕
                VStack(spacing: 16) {
                    ZStack {
                        // 点阵背景
                        WikiDotPattern(dotColor: .wikiBorder, spacing: 18, dotSize: 2)
                            .frame(width: 200, height: 100)
                            .opacity(0.5)

                        // 背景光晕
                        Circle()
                            .fill(Color.wikiAccent.opacity(0.08))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        // 主图标 + 发光
                        Image(systemName: "books.vertical.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.wikiAccent, .wikiConcept],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .wikiAccent.opacity(0.4), radius: 16, x: 0, y: 8)
                    }
                    .frame(height: 100)

                    Text(L.tr("page.wiki"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.wikiText)

                    Text(L.tr("welcome.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.top, 40)
                
                // Stats
                HStack(spacing: 20) {
                    StatCard(title: L.tr("stat.totalPages"), value: "\(store.totalPages)", icon: "doc.richtext.fill", color: .wikiAccent)
                    StatCard(title: L.tr("stat.entities"), value: "\(store.entityCount)", icon: "person.text.rectangle.fill", color: .wikiEntity)
                    StatCard(title: L.tr("stat.concepts"), value: "\(store.conceptCount)", icon: "lightbulb.fill", color: .wikiConcept)
                    StatCard(title: L.tr("stat.sources"), value: "\(store.sourceCount)", icon: "doc.plaintext.fill", color: .wikiSource)
                }
                .padding(.horizontal)

                // 空知识库引导
                if store.pages.isEmpty {
                    VStack(spacing: 16) {
                        // 标题区
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.wikiAccent)
                            Text(L.tr("welcome.quickStart"))
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }

                        GuideStepRow(number: 1, text: L.tr("welcome.guide.createPage"), icon: "doc.badge.plus")
                        GuideStepRow(number: 2, text: L.tr("welcome.guide.wikiLink"), icon: "link")
                        GuideStepRow(number: 3, text: L.tr("welcome.guide.browseGraph"), icon: "circle.hexagongrid.fill")
                        GuideStepRow(number: 4, text: L.tr("welcome.guide.search"), icon: "magnifyingglass")
                    }
                    .padding(20)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                }

                // 使用技巧（非空知识库时显示）
                if !store.pages.isEmpty {
                    HStack(spacing: 12) {
                        WikiGlow(icon: "lightbulb.fill", color: .wikiConcept, size: 24)

                        Text(L.tr("welcome.wikilinkHint"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.wikiAccent)
                        Text(L.tr("quickStart"))
                            .font(.headline)
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    QuickActionRow(icon: "plus.circle.fill", title: L.tr("action.createPage"), subtitle: L.tr("action.createPage.subtitle"), color: .wikiAccent) {
                        showCreateSheet = true
                    }
                    QuickActionRow(icon: "tray.and.arrow.down.fill", title: L.tr("action.ingestKnowledge"), subtitle: L.tr("action.ingestKnowledge.subtitle"), color: .wikiSource) {
                        selectedTab = .ingest
                    }
                    QuickActionRow(icon: "circle.hexagongrid.fill", title: L.tr("action.browseGraph"), subtitle: L.tr("action.browseGraph.subtitle"), color: .wikiConcept) {
                        selectedTab = .graph
                    }
                    QuickActionRow(icon: "stethoscope", title: L.tr("action.healthCheck"), subtitle: L.tr("action.healthCheck.subtitle"), color: .wikiComparison) {
                        selectedTab = .settings
                    }
                }
                .padding(.horizontal)
                
                // Recent Pages
                if !store.pages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.wikiAccent)
                            Text(L.tr("recentUpdates"))
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(Array(store.pages.sorted { $0.updated > $1.updated }.prefix(5))) { page in
                            PageRowView(page: page, compact: true)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Pinned / Favorite Pages
                let pinnedPages = store.pages.filter { $0.isPinned }
                if !pinnedPages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            WikiGlow(icon: "pin.fill", color: .wikiAccent, size: 20)
                            Label(L.tr("pinned"), systemImage: "pin.fill")
                                .font(.headline)
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(pinnedPages) { page in
                            PageRowView(page: page, compact: true)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.wikiBackground)
        .sheet(isPresented: $showCreateSheet) {
            CreatePageView()
        }
    }
}
