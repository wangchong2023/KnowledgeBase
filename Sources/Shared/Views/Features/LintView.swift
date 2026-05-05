// LintView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的“健康检查”与“系统治理”中心（LintView），是确保知识库结构完整性与质量的核心视图。
// 系统通过以下维度对知识库进行全自动审计与优化建议：
// 1. 结构化审计：自动检测断开的链接（Broken Links）、孤儿页面（Orphan Pages）及循环引用，维护知识图谱的逻辑拓扑。
// 2. 健康评分系统：基于页面规模、链接密度及错误率计算实时健康分，通过 Dashboard 直观展示知识库的整体质量水平。
// 3. AI 治理建议：集成 LLM 对知识内容进行深度扫描，识别可合并的重复概念、建议拆分的冗余文档，并自动发现潜在的关联节点。
// 4. 自动化修复流程：提供一键修复按钮与快捷跳转功能，支持通过 AI 智能补全缺失元数据，显著降低知识维护的人力成本。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 修复返回按钮交互 Bug，完成全工程文档与魔鬼数字规范化升级
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - 治理中心入口
/// 知识治理中心主视图容器
/// 负责为健康检查与 AI 建议提供独立的导航上下文，管理顶层治理生命周期
struct LintView: View {
    @Binding var selection: SidebarSelection?
    var body: some View {
        LintViewContent(selection: $selection)
    }
}

// MARK: - 治理中心核心
/// 知识治理核心内容视图
/// 负责健康得分看板（Dashboard）渲染、结构化问题分析、AI 治理建议展示及自动化修复逻辑
struct LintViewContent: View {
    @Binding var selection: SidebarSelection?
    @Environment(KMStore.self) var store
    @Environment(AIWorkflowStore.self) var aiStore
    @Environment(AppRouter.self) var router
    @Environment(\.dismiss) var dismiss // 新增：用于强制退出层级
    @State private var isRunning = false
    @State private var selectedTab = 0 // 0: 健康检查, 1: AI 建议

    // MARK: - UI Helpers
    private var healthColor: Color {
        switch aiStore.healthLevel {
        case .excellent: return .green
        case .good: return .wikiAccent
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private var buttonGradient: Color {
        selectedTab == 0 ? .blue : .purple
    }

    var body: some View {
        VStack(spacing: 0) {
            // 选项卡切换
            Picker("", selection: $selectedTab) {
                Text(L10n.Lint.tr("title")).tag(0)
                Text(L10n.Lint.tr("aiSuggestions")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(WikiUI.containerBackground)

            // 内容区
            Group {
                if selectedTab == 0 {
                    healthCheckSection
                } else {
                    aiSuggestionsSection
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color.wikiBackground)
        .navigationTitle(selectedTab == 0 ? L10n.Lint.tr("title") : L10n.Lint.tr("aiSuggestions"))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    // 修复：优先使用 dismiss() 退出当前模态或 Push 栈，兜底使用路由返回
                    if selection != nil {
                        selection = nil // 如果是侧边栏选中的，清空选中状态以返回
                    } else {
                        dismiss()
                        router.pop()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: WikiUI.subheadlineFontSize, weight: .bold))
                        .foregroundStyle(.wikiText)
                        .frame(width: WikiUI.titleIconSize * 1.3, height: WikiUI.titleIconSize * 1.3)
                        .background(WikiUI.containerBackground)
                        .clipShape(Circle())
                        .contentShape(Circle()) // 确保热区完整
                        .shadow(color: .black.opacity(0.1), radius: 2)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    if selectedTab == 0 { runLint() } else { runAIScan() }
                }) {
                    HStack(spacing: 8) {
                        // 使用固定身份的 ZStack 和透明度切换，彻底杜绝重影
                        ZStack {
                            ProgressView()
                                .controlSize(.small)
                                .opacity(isRunning || aiStore.isScanningAI ? 1 : 0)
                            
                            Image(systemName: selectedTab == 0 ? "stethoscope" : "sparkles")
                                .opacity(isRunning || aiStore.isScanningAI ? 0 : 1)
                        }
                        .frame(width: 20)
                        
                        Text(isRunning || aiStore.isScanningAI ? L10n.Lint.tr("scanning") : (selectedTab == 0 ? L10n.Lint.tr("runCheck") : L10n.Lint.tr("runAIScan")))
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(buttonGradient.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(buttonGradient.opacity(0.1), lineWidth: 1)
                    )
                    .foregroundStyle(buttonGradient)
                }
                .buttonStyle(.plain)
                .disabled(isRunning || aiStore.isScanningAI)
                .transaction { transaction in
                    transaction.animation = nil // 强制禁用过渡动画，从事务层面防止重影
                }
            }
        }
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
                if !aiStore.lintIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.Lint.tr("detailIssues"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            issueSection(title: Localized.trf("lint.errors", aiStore.lintIssues.filter { $0.severity == .error }.count), 
                                         issues: aiStore.lintIssues.filter { $0.severity == .error }, 
                                         icon: "xmark.circle.fill", color: .red)
                            
                            issueSection(title: Localized.trf("lint.warnings", aiStore.lintIssues.filter { $0.severity == .warning }.count), 
                                         issues: aiStore.lintIssues.filter { $0.severity == .warning }, 
                                         icon: "exclamationmark.triangle.fill", color: .orange)
                            
                            issueSection(title: Localized.trf("lint.tips", aiStore.lintIssues.filter { $0.severity == .info }.count), 
                                         issues: aiStore.lintIssues.filter { $0.severity == .info }, 
                                         icon: "info.circle.fill", color: .blue)
                        }
                        .wikiContainer(cornerRadius: 16, padding: false)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var healthDashboardHeader: some View {
        VStack(spacing: 20) {
            ZStack {
                // 上次检查时间展示在左上角
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Lint.tr("lastCheck.title"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.wikiSecondary)
                        
                        if let date = aiStore.lastLintDate {
                            Text(formatDate(date))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.wikiText)
                        } else {
                            Text(L10n.Lint.tr("lastCheck.never"))
                                .font(.system(size: 10))
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .wikiContainer(cornerRadius: 10, padding: true)
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(healthColor.opacity(0.08), lineWidth: 14)
                            .frame(width: 135, height: 135) // 进一步缩小圆圈，彻底解决与左侧信息的重叠
                        
                        // 进度环
                        Circle()
                            .trim(from: 0, to: CGFloat(aiStore.lintScore) / 100.0)
                            .stroke(
                                LinearGradient(colors: [healthColor.opacity(0.6), healthColor], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: 135, height: 135)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(aiStore.lintScore)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundStyle(.wikiText)
                            Text(L10n.Lint.tr("health.score"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    Spacer()
                }
                
                // 评分标准展示在右下角
                VStack(alignment: .trailing, spacing: 6) {
                    let ranges = [
                        (L10n.Lint.tr("health.excellent"), "90-100"),
                        (L10n.Lint.tr("health.good"), "70-89"),
                        (L10n.Lint.tr("health.fair"), "50-69"),
                        (L10n.Lint.tr("health.poor"), "< 50")
                    ]
                    
                    ForEach(ranges, id: \.1) { label, range in
                        HStack(spacing: 4) {
                            Text(label)
                                .font(.system(size: 9))
                                .frame(width: 30, alignment: .trailing)
                            Text(range)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.wikiSecondary.opacity(0.8))
                                .frame(width: 45, alignment: .leading)
                        }
                    }
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.wikiSecondary)
                .padding(12)
                .background(WikiUI.containerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
                )
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(height: 180)
            
            Text(aiStore.healthLevel.title)
                .font(.headline.bold())
                .foregroundStyle(healthColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(healthColor.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(healthColor.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            metricCard(title: L10n.Lint.tr("metric.pages"), 
                       value: "\(store.pages.count)", 
                       icon: "doc.text.fill", 
                       color: .blue)
            
            metricCard(title: L10n.Lint.tr("metric.broken"), 
                       value: "\(store.brokenLinkCount)", 
                       icon: "link.badge.plus", 
                       color: .red)
            
            metricCard(title: L10n.Lint.tr("metric.orphans"), 
                       value: "\(store.orphanPageCount)", 
                       icon: "person.fill.questionmark", 
                       color: .orange)
            
            metricCard(title: L10n.Lint.tr("metric.links"), 
                       value: "\(store.totalConnectionCount)", 
                       icon: "point.3.connected.trianglepath.dotted", 
                       color: .wikiAccent)
        }
        .padding(.horizontal, 16)
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.wikiSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(WikiUI.containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WikiUI.containerBorder, lineWidth: WikiUI.borderWidth)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    // MARK: - AI 建议板块
    private var aiSuggestionsSection: some View {
        Group {
            if aiStore.refactorSuggestions.isEmpty && aiStore.potentialLinks.isEmpty {
                emptyAIView
            } else {
                List {
                    if !aiStore.refactorSuggestions.isEmpty {
                        Section(L10n.Lint.tr("refactorSection")) {
                            ForEach(aiStore.refactorSuggestions) { suggestion in
                                RefactorSuggestionRow(suggestion: suggestion)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                aiStore.removeRefactorSuggestion(id: suggestion.id)
                                            }
                                        } label: {
                                            Label(L10n.Common.tr("ignore"), systemImage: "eye.slash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    if !aiStore.potentialLinks.isEmpty {
                        Section(L10n.Lint.tr("linkDiscoverySection")) {
                            ForEach(aiStore.potentialLinks) { link in
                                PotentialLinkRow(link: link)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                aiStore.removePotentialLink(id: link.id)
                                            }
                                        } label: {
                                            Label(L10n.Common.tr("ignore"), systemImage: "eye.slash")
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
            Text(L10n.Lint.tr("noIssues"))
                .font(.title3.weight(.semibold))
            Text(L10n.Lint.tr("noIssuesHint"))
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
            Text(L10n.Lint.tr("noAISuggestions"))
                .font(.title3.weight(.semibold))
            Text(L10n.Lint.tr("noAISuggestionsHint"))
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

    private func runLint() {
        isRunning = true
        Task {
            // 模拟扫描耗时，增加视觉反馈
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await aiStore.runLint()
            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func runAIScan() {
        Task {
            await aiStore.runAIScan()
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
                
                Button(L10n.Lint.tr("apply")) {
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
            
            Button(L10n.Lint.tr("apply")) {
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


// MARK: - 质量问题行渲染
/// 单个知识质量问题的展示行组件
/// 负责展示特定质量问题的详情、修复建议，并提供 AI 深度分析入口及页面快捷跳转能力
struct LintIssueRow: View {
    let issue: LintIssue
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
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
            .frame(maxWidth: .infinity, alignment: .leading)

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
                    Button(action: { router.navigateToPage(id: pageID) }) {
                        Text(L10n.Lint.tr("goToPage"))
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
                                Text(L10n.Lint.tr("aiFixSuggestion"))
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
        
        Task {
            do {
                let suggestion = try await store.aiWorkflowStore.fetchFixSuggestion(for: issue)
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
