@preconcurrency import SwiftUI

/// 知识资产仪表盘 (Designer & PM 视角：可视化知识价值)
@MainActor
struct KnowledgeDashboardView: View {
    @Environment(KMStore.self) var store
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 核心资产统计
                HStack(spacing: 16) {
                    MetricBox(title: Localized.tr("dashboard.totalPages"), value: "\(store.pages.count)", icon: "doc.on.doc", color: .blue)
                    MetricBox(title: Localized.tr("dashboard.totalLinks"), value: "\(totalLinks)", icon: "link", color: .wikiAccent)
                }
                .padding(.horizontal)
                
                // 2. 连接密度图 (模拟可视化)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Text(Localized.tr("dashboard.density"))
                            .font(.headline)
                        
                        Button {
                            showDensityInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .popover(isPresented: $showDensityInfo) {
                            Text(Localized.tr("dashboard.density.desc"))
                                .font(.caption)
                                .padding()
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                    .padding(.horizontal)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.wikiCard)
                            .frame(height: 200)
                        
                        // 简易可视化模拟：连接分布
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(0..<12) { index in
                                Capsule()
                                    .fill(LinearGradient(colors: [.wikiAccent.opacity(0.3), .wikiAccent], startPoint: .bottom, endPoint: .top))
                                    .frame(width: 12, height: CGFloat.random(in: 40...160))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 3. 每日闪念 (Smart Recap)
                DailyRecapSection()
                    .padding(.horizontal)
                
                // 4. 热门领域
                VStack(alignment: .leading, spacing: 12) {
                    Text(Localized.tr("dashboard.hotTopics"))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(tags, id: \.tag) { tagInfo in
                            HStack {
                                Text("#\(tagInfo.tag)")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(tagInfo.count)")
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                            .padding()
                            .background(Color.wikiCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.dashboard"))
        .task {
            self.tags = await store.getAllTags()
        }
    }
    
    @State private var tags: [(tag: String, count: Int)] = []
    @State private var showDensityInfo = false
    
    private var totalLinks: Int {
        store.pages.reduce(0) { $0 + $1.outgoingLinks.count }
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// 每日闪念区域 (PM 视角：主动召回交互)
struct DailyRecapSection: View {
    @Environment(KMStore.self) var store
    @State private var recap: KnowledgeInsightService.DailyRecap?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Localized.tr("dashboard.dailyInsights"))
                    .font(.headline)
                Spacer()
                Button(action: loadRecap) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let recap = recap {
                Button {
                    if let target = store.pages.first(where: { $0.title == recap.targetPageTitle }) {
                        store.navigationPath.append(target)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recap.targetPageTitle)
                            .font(.subheadline.bold())
                            .foregroundStyle(.wikiAccent)
                        
                        MarkdownRendererView(
                            content: recap.insight,
                            isPrivate: false,
                            onLinkTap: { _ in }
                        )
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text(recap.suggestedConnection)
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                Text(Localized.tr("dashboard.dailyInsights.refresh"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .onAppear {
            if recap == nil { loadRecap() }
        }
    }
    
    private func loadRecap() {
        guard !isLoading else { return }
        isLoading = true
        let svc = self.store.insightService
        let llm = self.store.llmService
        let pages = self.store.pages
        Task {
            do {
                let result = try await svc.generateDailyRecap(pages: pages, llmService: llm)
                await MainActor.run {
                    self.recap = result
                    self.isLoading = false
                    HapticManager.shared.trigger(.success)
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}
