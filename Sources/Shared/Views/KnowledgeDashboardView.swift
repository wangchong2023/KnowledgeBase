@preconcurrency import SwiftUI

/// 知识资产仪表盘 (Designer & PM 视角：可视化知识价值)
@MainActor
struct KnowledgeDashboardView: View {
    @Environment(KMStore.self) var store
    @State private var tags: [(tag: String, count: Int)] = []
    @State private var showDensityInfo = false
    
    private var totalLinks: Int {
        store.pages.reduce(0) { $0 + $1.outgoingLinks.count }
    }
    
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
                            ForEach(0..<12) { _ in
                                Capsule()
                                    .fill(LinearGradient(colors: [.wikiAccent.opacity(0.3), .wikiAccent], startPoint: .bottom, endPoint: .top))
                                    .frame(width: 12, height: CGFloat.random(in: 40...160))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 3. 每日闪念
                DailyRecapSection()
                    .padding(.horizontal)
                
                // 4. 热门领域
                VStack(alignment: .leading, spacing: 12) {
                    Text(Localized.tr("dashboard.hotTopics"))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(tags, id: \.tag) { tagInfo in
                            NavigationLink(destination: TagCloudView(initialTag: tagInfo.tag)) {
                                HotTopicCard(tag: tagInfo.tag, count: tagInfo.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 5. 荣誉奖章
                NavigationLink(destination: MedalWallView()) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Localized.tr("medal.wall.title"))
                                .font(.headline)
                                .foregroundStyle(.wikiText)
                            Text(Localized.trf("medal.wall.count", MedalService.shared.earnedMedalIDs.count))
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.wikiSecondary.opacity(0.5))
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.wikiBorder.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.dashboard"))
        .task {
            await loadTags()
        }
        .onChange(of: store.refreshTrigger) { _, _ in
            Task { await loadTags() }
        }
    }
    
    private func loadTags() async {
        let allTags = await store.getAllTags()
        await MainActor.run {
            self.tags = allTags
        }
    }
}

// MARK: - Subviews

private struct HotTopicCard: View {
    let tag: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tagColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: tagIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tagColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tag)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                Text("\(count) \(Localized.tr("dashboard.pages"))")
                    .font(.system(size: 10))
                    .foregroundStyle(.wikiSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 保持文案左对齐，但容器撑满
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.wikiSecondary.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wikiBorder.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    private var tagIcon: String {
        let t = tag.lowercased()
        if t.contains("ai") || t.contains("智能") || t.contains("artificial intelligence") { return "sparkles" }
        if t.contains("rag") || t.contains("检索") || t.contains("retrieval") { return "magnifyingglass.circle" }
        if t.contains("图谱") || t.contains("graph") || t.contains("knowledge base") { return "circle.hexagongrid.fill" }
        if t.contains("入门") || t.contains("guide") || t.contains("tutorial") { return "map" }
        if t.contains("开发") || t.contains("code") || t.contains("dev") { return "terminal" }
        if t.contains("欢迎") || t.contains("welcome") { return "hand.wave" }
        if t.contains("可视化") || t.contains("chart") || t.contains("visual") { return "chart.bar" }
        return "tag"
    }
    
    private var tagColor: Color {
        let hash = tag.hashValue
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }
}

private struct MetricBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

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
        Task {
            do {
                let pages = store.pages
                if pages.count < 3 {
                    await MainActor.run { isLoading = false }
                    return
                }
                let result = try await store.insightService.generateDailyRecap(pages: pages, llmService: store.llmService, forceRefresh: true)
                await MainActor.run {
                    self.recap = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
