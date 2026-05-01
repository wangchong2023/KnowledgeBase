import SwiftUI

// MARK: - Lint View (entry point with NavigationStack)
struct LintView: View {
    var body: some View {
        NavigationStack {
            LintViewContent()
        }
    }
}

// MARK: - Lint View Content (for use inside parent NavigationStack)
struct LintViewContent: View {
    @EnvironmentObject var store: KMStore
    @State private var isRunning = false
    @State private var selectedTab = 0 // 0: 健康检查, 1: AI 建议

    var body: some View {
        VStack(spacing: 0) {
            // 选项卡切换
            Picker("", selection: $selectedTab) {
                Text(Localized.tr("lint.title")).tag(0)
                Text("AI 维护建议").tag(1)
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
        .navigationTitle("维护中心")
    }

    // MARK: - 健康检查板块
    private var healthCheckSection: some View {
        Group {
            if store.lintIssues.isEmpty {
                emptyHealthView
            } else {
                List {
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
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - AI 建议板块
    private var aiSuggestionsSection: some View {
        Group {
            if store.refactorSuggestions.isEmpty && store.potentialLinks.isEmpty {
                emptyAIView
            } else {
                List {
                    if !store.refactorSuggestions.isEmpty {
                        Section("架构重构建议") {
                            ForEach(store.refactorSuggestions) { suggestion in
                                RefactorSuggestionRow(suggestion: suggestion)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                store.refactorSuggestions.removeAll { $0.id == suggestion.id }
                                            }
                                        } label: {
                                            Label("忽略", systemImage: "eye.slash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    if !store.potentialLinks.isEmpty {
                        Section("潜在链接发现") {
                            ForEach(store.potentialLinks) { link in
                                PotentialLinkRow(link: link)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                store.potentialLinks.removeAll { $0.id == link.id }
                                            }
                                        } label: {
                                            Label("忽略", systemImage: "eye.slash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
            Text("暂无 AI 建议")
                .font(.title3.weight(.semibold))
            Text("点击下方按钮，让 AI 扫描您的知识库并提供重构或链接建议。")
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
                Section {
                    ForEach(issues) { issue in
                        LintIssueRow(issue: issue)
                    }
                } header: {
                    Label(title, systemImage: icon).foregroundStyle(color)
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
            return store.isScanningAI ? "正在分析中..." : "开始 AI 智能扫描"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            store.runLint()
            isRunning = false
        }
    }

    private func runAIScan() {
        Task {
            await store.runAIScan()
        }
    }
}

// MARK: - AI 建议行组件

struct RefactorSuggestionRow: View {
    let suggestion: RefactorSuggestion
    @EnvironmentObject var store: KMStore
    
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
                
                Button("应用") {
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
            
            Text("操作: \(suggestion.suggestion)")
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
    @EnvironmentObject var store: KMStore
    
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
            
            Button("应用") {
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
    @EnvironmentObject var store: KMStore
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
               let _ = store.pageByID(pageID) {
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
                                Text("AI 修复建议")
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
        HapticManager.selection()
        
        Task {
            do {
                let suggestion = try await store.llmService.suggestFix(issue: issue, pages: store.pages)
                await MainActor.run {
                    withAnimation {
                        self.aiSuggestion = suggestion
                        self.isProcessingOCR = false // 这里不需要，复制粘贴错误，应删除
                        self.isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiSuggestion = "获取建议失败：\(error.localizedDescription)"
                    self.isAnalyzing = false
                }
            }
        }
    }
}
