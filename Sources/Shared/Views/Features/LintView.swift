import SwiftUI

// MARK: - 健康检查视图 (导航入口)
struct LintView: View {
    var body: some View {
        LintViewContent()
    }
}

// MARK: - 健康检查核心内容 ( Dashboard 模式)
struct LintViewContent: View {
    @Environment(KMStore.self) var store
    @State private var isRunning = false
    @State private var selectedTab = 0 // 0: 健康检查, 1: AI 建议

    // MARK: - 核心计算指标
    private var score: Int {
        let errorCount = store.lintIssues.filter { $0.severity == .error }.count
        let warningCount = store.lintIssues.filter { $0.severity == .warning }.count
        let infoCount = store.lintIssues.filter { $0.severity == .info }.count
        
        let deduction = (errorCount * 10) + (warningCount * 5) + (infoCount * 2)
        return max(0, 100 - deduction)
    }
    
    private var healthLabel: String {
        if score >= 90 { return Localized.tr("lint.health.excellent") }
        if score >= 70 { return Localized.tr("lint.health.good") }
        if score >= 50 { return Localized.tr("lint.health.fair") }
        return Localized.tr("lint.health.poor")
    }
    
    private var healthColor: Color {
        if score >= 90 { return .green }
        if score >= 70 { return .wikiAccent }
        if score >= 50 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 0) {
            // 选项卡切换
            Picker("", selection: $selectedTab) {
                Text(Localized.tr("lint.title")).tag(0)
                Text(Localized.tr("lint.aiSuggestions")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color.wikiCard)

            // 内容区
            Group {
                if selectedTab == 0 {
                    healthCheckSection
                } else {
                    aiSuggestionsSection
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // 操作栏
            bottomActionBar
        }
        .background(Color.wikiBackground)
        .navigationTitle(selectedTab == 0 ? Localized.tr("lint.title") : Localized.tr("lint.aiSuggestions"))
    }

    // MARK: - 健康检查板块 (重构为 Dashboard 模式)
    private var healthCheckSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Dashboard Header
                healthDashboardHeader
                    .padding(.top)

                // 2. Metrics Grid
                metricsGrid
                
                // 3. Issue List (如果存在问题)
                if !store.lintIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Localized.tr("lint.detailIssues"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            issueSection(title: Localized.trf("lint.errors", store.lintIssues.filter { $0.severity == .error }.count), 
                                         issues: store.lintIssues.filter { $0.severity == .error }, 
                                         icon: "xmark.circle.fill", color: .red)
                            
                            issueSection(title: Localized.trf("lint.warnings", store.lintIssues.filter { $0.severity == .warning }.count), 
                                         issues: store.lintIssues.filter { $0.severity == .warning }, 
                                         icon: "exclamationmark.triangle.fill", color: .orange)
                            
                            issueSection(title: Localized.trf("lint.tips", store.lintIssues.filter { $0.severity == .info }.count), 
                                         issues: store.lintIssues.filter { $0.severity == .info }, 
                                         icon: "info.circle.fill", color: .blue)
                        }
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var healthDashboardHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // 上次检查时间展示在左上角
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localized.tr("lint.lastCheck.title"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.wikiSecondary)
                    
                    if let date = store.lastLintDate {
                        Text(formatDate(date))
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(Localized.tr("lint.lastCheck.never"))
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .background(Color.wikiCard.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                HStack {
                    Spacer()
                    ZStack {
                        // 背景环
                        Circle()
                            .stroke(healthColor.opacity(0.1), lineWidth: 15)
                            .frame(width: 160, height: 160)
                        
                        // 进度环
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100.0)
                            .stroke(
                                AngularGradient(colors: [healthColor.opacity(0.6), healthColor], center: .center),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text(Localized.tr("lint.health.score"))
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    Spacer()
                }
                
                // 评分标准展示在右下角
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(Localized.tr("lint.health.excellent"))
                        Text("90-100")
                            .foregroundStyle(.wikiSecondary.opacity(0.8))
                    }
                    HStack(spacing: 6) {
                        Text(Localized.tr("lint.health.good"))
                        Text("70-89")
                            .foregroundStyle(.wikiSecondary.opacity(0.8))
                    }
                    HStack(spacing: 6) {
                        Text(Localized.tr("lint.health.fair"))
                        Text("50-69")
                            .foregroundStyle(.wikiSecondary.opacity(0.8))
                    }
                    HStack(spacing: 6) {
                        Text(Localized.tr("lint.health.poor"))
                        Text("< 50")
                            .foregroundStyle(.wikiSecondary.opacity(0.8))
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.wikiSecondary)
                .padding(10)
                .background(Color.wikiCard.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
                )
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(height: 180)
            
            Text(healthLabel)
                .font(.title3.bold())
                .foregroundStyle(healthColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(healthColor.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(title: Localized.tr("lint.metric.pages"), 
                       value: "\(store.pages.count)", 
                       icon: "doc.text.fill", 
                       color: .blue)
            
            let brokenCount = store.lintIssues.filter { $0.type == .brokenLink }.count
            metricCard(title: Localized.tr("lint.metric.broken"), 
                       value: "\(brokenCount)", 
                       icon: "link.badge.plus", 
                       color: .red)
            
            let islandCount = store.lintIssues.filter { $0.type == .island || $0.type == .orphan }.count
            metricCard(title: Localized.tr("lint.metric.orphans"), 
                       value: "\(islandCount)", 
                       icon: " person.fill.questionmark", 
                       color: .orange)
            
            // 这里可以接入图谱洞察，目前先用活跃连接数
            let connectionCount = store.pages.reduce(0) { $0 + $1.outgoingLinks.count }
            metricCard(title: Localized.tr("lint.metric.links"), 
                       value: "\(connectionCount)", 
                       icon: "point.3.connected.trianglepath.dotted", 
                       color: .wikiAccent)
        }
        .padding(.horizontal)
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.wikiText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - AI 建议板块
    private var aiSuggestionsSection: some View {
        Group {
            if store.refactorSuggestions.isEmpty && store.potentialLinks.isEmpty {
                emptyAIView
            } else {
                List {
                    if !store.refactorSuggestions.isEmpty {
                        Section(Localized.tr("lint.refactorSection")) {
                            ForEach(store.refactorSuggestions) { suggestion in
                                RefactorSuggestionRow(suggestion: suggestion)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                store.refactorSuggestions.removeAll { $0.id == suggestion.id }
                                            }
                                        } label: {
                                            Label(Localized.tr("misc.ignore"), systemImage: "eye.slash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    if !store.potentialLinks.isEmpty {
                        Section(Localized.tr("lint.linkDiscoverySection")) {
                            ForEach(store.potentialLinks) { link in
                                PotentialLinkRow(link: link)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                store.potentialLinks.removeAll { $0.id == link.id }
                                            }
                                        } label: {
                                            Label(Localized.tr("misc.ignore"), systemImage: "eye.slash")
                                        }
                                    }
                            }
                        }
                    }
                }
#if os(iOS)
                .listStyle(.insetGrouped)
#endif
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyHealthView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(Localized.tr("lint.noIssues"))
                .font(.title3.weight(.semibold))
            Text(Localized.tr("lint.noIssuesHint"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            Spacer()
        }
    }

    private var emptyAIView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.wikiAccent)
            Text(Localized.tr("lint.noAISuggestions"))
                .font(.title3.weight(.semibold))
            Text(Localized.tr("lint.noAISuggestionsHint"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private func issueSection(title: String, issues: [LintIssue], icon: String, color: Color) -> some View {
        Group {
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Label(title, systemImage: icon)
                            .font(.subheadline.bold())
                            .foregroundStyle(color)
                        Spacer()
                    }
                    .padding()
                    .background(color.opacity(0.05))
                    
                    VStack(spacing: 0) {
                        ForEach(issues) { issue in
                            LintIssueRow(issue: issue)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            
                            if issue.id != issues.last?.id {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 16) {
            Button(action: {
                if selectedTab == 0 { runLint() } else { runAIScan() }
            }) {
                HStack(spacing: 8) {
                    if isRunning || store.isScanningAI {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: selectedTab == 0 ? "stethoscope" : "sparkles")
                    }
                    Text(buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonGradient)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                .foregroundStyle(.white)
            }
            .disabled(isRunning || store.isScanningAI)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.wikiCard)
    }

    private var buttonTitle: String {
        if selectedTab == 0 {
            return isRunning ? Localized.tr("lint.checking") : Localized.tr("lint.runCheck")
        } else {
            return store.isScanningAI ? Localized.tr("lint.aiScanning") : Localized.tr("lint.runAIScan")
        }
    }

    private var buttonGradient: LinearGradient {
        if selectedTab == 0 {
            return LinearGradient(colors: [.wikiComparison, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.wikiAccent, .purple], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func runLint() {
        isRunning = true
        Task {
            // 模拟扫描耗时，增加视觉反馈
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            store.runLint()
            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func runAIScan() {
        Task {
            await store.runAIScan()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - AI 建议行组件

struct RefactorSuggestionRow: View {
    let suggestion: RefactorSuggestion
    @Environment(KMStore.self) var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(suggestion.type.uppercased(), systemImage: iconName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.2))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
                
                Text(suggestion.target)
                    .font(.subheadline.bold())
                
                Spacer()
                
                Button(Localized.tr("lint.apply")) {
                    withAnimation {
                        store.applyRefactorSuggestion(suggestion)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.wikiAccent)
            }
            
            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
            
            Text(Localized.trf("lint.aiFixSuggestion", suggestion.suggestion))
                .font(.caption2)
                .padding(6)
                .background(Color.wikiBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch suggestion.type {
        case "merge": return "arrow.merge"
        case "split": return "arrow.branch"
        case "rename": return "character.cursor.ibeam"
        default: return "sparkles"
        }
    }
    
    private var color: Color {
        switch suggestion.type {
        case "merge": return .orange
        case "split": return .purple
        case "rename": return .blue
        default: return .wikiAccent
        }
    }
}

struct PotentialLinkRow: View {
    let link: PotentialLinkSuggestion
    @Environment(KMStore.self) var store
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.sourceTitle)
                    .font(.subheadline.bold())
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text("[[\(link.targetTitle)]]")
                        .font(.caption)
                        .foregroundStyle(.wikiAccent)
                }
            }
            
            Spacer()
            
            Button(Localized.tr("lint.apply")) {
                withAnimation {
                    store.applyPotentialLink(link)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Lint Issue Row
struct LintIssueRow: View {
    let issue: LintIssue
    @Environment(KMStore.self) var store
    @State private var aiSuggestion: String?
    @State private var isAnalyzing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: issue.type.icon)
                    .foregroundStyle(issue.severity.color)
                    .frame(width: 16, height: 16)

                Text(issue.message)
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)
            }

            if !issue.suggestion.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(issue.suggestion)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.leading, 24)
            }

            if let pageID = issue.pageID,
               store.pages.contains(where: { $0.id == pageID }) {
                HStack(spacing: 12) {
                    Button(action: { store.selectedPageID = pageID }) {
                        Text(Localized.tr("lint.goToPage"))
                            .font(.caption2)
                            .foregroundStyle(.wikiAccent)
                    }
                    
                    if store.llmService.isEnabled {
                        Button(action: fetchAISuggestion) {
                            HStack(spacing: 4) {
                                if isAnalyzing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                }
                                Text(Localized.tr("lint.aiFixSuggestion"))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.purple)
                        }
                        .disabled(isAnalyzing)
                    }
                }
                .padding(.leading, 24)
            }
            
            if let suggestion = aiSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.leading, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func fetchAISuggestion() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        HapticManager.shared.trigger(.selection)
        
        Task {
            do {
                let suggestion = try await AISynthesisService.shared.suggestFix(issue: issue, pages: store.pages)
                await MainActor.run {
                    withAnimation {
                        self.aiSuggestion = suggestion
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiSuggestion = Localized.trf("lint.aiSuggestionError", error.localizedDescription)
                    self.isAnalyzing = false
                }
            }
        }
    }
}
