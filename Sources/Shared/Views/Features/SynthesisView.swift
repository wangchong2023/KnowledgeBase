// SynthesisView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的“知识合成”功能（SynthesisView），利用 LLM 能力将零散的知识点转化为结构化的高级产出。
// 视图通过以下核心功能点提升知识的内化效率与二次传播价值：
// 1. 多模态合成入口：提供思维导图、互动测验、演示幻灯片、调研报告及可视化信息图的生成入口，支持一键触发异步生成任务。
// 2. 任务状态追踪：深度集成 TaskCenter，实时展示生成任务的进度与状态，支持在后台执行大规模知识处理任务。
// 3. 文档全生命周期管理：实现了生成结果的分组展示、重命名、批量删除及预览功能，支持将合成内容导出为 PDF 或文本格式。
// 4. 深度交互体验：支持 Mermaid 图表实时渲染、互动测验交互及 PDF 预览，确保合成后的知识内容不仅可读而且可用。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化 UI 常量与物理常数
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 合成视图入口
/// 知识合成功能主视图
/// 负责利用 LLM 将分散知识转化为思维导图、测验、报告等高级结构化产出，并管理生成文档的生命周期
struct SynthesisView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: AppTab
    @Environment(KMStore.self) var store
    @Environment(SynthesisStore.self) var synthesisStore
    @ObservedObject var taskCenter = TaskCenter.shared
    @State private var showOutput = false
    @State private var outputType: SynthesisStore.SynthesisType = .mindmap
    @State private var selectedDoc: SynthesisStore.SynthesisDocument?
    @State private var pdfURL: IdentifiableURL?

    @State private var exportError: String?
    @State private var showExportError = false
    @State private var docToRename: SynthesisStore.SynthesisDocument?
    @State private var newDocName = ""
    @State private var docToDelete: SynthesisStore.SynthesisDocument?
    @State private var showDeleteDocConfirm = false
    @State private var showRenameDialog = false
    
    @State private var editMode: EditMode = .inactive
    @State private var selectedDocIDs = Set<UUID>()
    @State private var showLimitAlert = false
    @State private var showNoPagesAlert = false
    @State private var expandedSynthesisSections: Set<SynthesisStore.SynthesisType> = Set(SynthesisStore.SynthesisType.allCases)
    @State private var showClearAllConfirm = false
    @State private var showBatchDeleteConfirm = false
    @State private var showLLMAlert = false

    /**
     * @description: 触发全局知识合成任务，聚合所有 Wiki 页面内容并提交给 SynthesisStore
     * @param {SynthesisType} type 合成产出的目标类型
     * @return {*}
     */
    private func performSynthesis(type: SynthesisStore.SynthesisType) {
        let combinedContent = store.pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        synthesisStore.performSynthesis(type: type, combinedContent: combinedContent)
    }
    
    var body: some View {
        @Bindable var synthesisStore = synthesisStore
        let runningTasks = taskCenter.tasks.filter { task in
            guard task.type == .synthesis else { return false }
            if case .running = task.status { return true }
            return false
        }
        
        return ScrollView {
            VStack(spacing: 24) {
                // 1. 合成操作入口
                synthesisEntryView
                
                // 2. 正在运行的任务
                if !runningTasks.isEmpty {
                    runningTasksSection(tasks: runningTasks)
                }
                
                // 3. 文档列表区域
                documentListArea
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            // ══ 弹窗锚点注入点 (挂载在内层容器以确保居中) ══
            .alert(L10n.Synthesis.tr("error.noPages"), isPresented: $showNoPagesAlert) {
                Button(L10n.Common.tr("ok"), role: .cancel) { }
            }
            .alert(L10n.Synthesis.tr("error.limitReached"), isPresented: $showLimitAlert) {
                Button(L10n.Common.tr("done"), role: .cancel) { }
            }
            .alert(Localized.tr("tag.rename"), isPresented: $showRenameDialog) {
                 TextField(Localized.tr("tags.inputName"), text: $newDocName)
                 Button(Localized.tr("tag.rename")) {
                     if let doc = docToRename {
                         synthesisStore.renameSynthesisDoc(type: doc.type, docID: doc.id, newName: newDocName)
                     }
                 }
                 Button(L10n.Common.tr("cancel"), role: .cancel) { }
            }
            .alert(Localized.tr("chat.configureFirst"), isPresented: $showLLMAlert) {
                Button(L10n.Common.tr("confirm"), role: .cancel) { }
            } message: {
                Text(Localized.tr("llm.error.notConfigured"))
            }
            .confirmationDialog(Localized.tr("synthesis.batchDeleteConfirm"), isPresented: $showBatchDeleteConfirm, titleVisibility: .visible) {
                Button(L10n.Common.tr("delete"), role: .destructive) {
                    batchDelete()
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { }
            }
            .confirmationDialog(L10n.Common.tr("deleteConfirm"), isPresented: $showDeleteDocConfirm, titleVisibility: .visible) {
                Button(L10n.Common.tr("delete"), role: .destructive) {
                    if let doc = docToDelete {
                        synthesisStore.deleteSynthesisDoc(type: doc.type, docID: doc.id)
                        HapticFeedback.shared.trigger(.success)
                    }
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { }
            }
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.synthesis"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { backButton }
        }
        .sheet(isPresented: $showOutput) { outputSheet }
        .sheet(item: $pdfURL) { identifiable in
            PDFPreviewWrapper(url: identifiable.url)
        }
    }

    /// 文档列表聚合区域
    private var documentListArea: some View {
        VStack(alignment: .leading, spacing: WikiUI.medium) {
            listHeader
            
            VStack(spacing: 0) {
                ForEach(SynthesisStore.SynthesisType.allCases) { type in
                    SynthesisTypeSection(
                        type: type,
                        expandedSections: $expandedSynthesisSections,
                        selectedDocIDs: $selectedDocIDs,
                        selectedDoc: $selectedDoc,
                        showOutput: $showOutput,
                        docToRename: $docToRename,
                        newDocName: $newDocName,
                        showRenameDialog: $showRenameDialog,
                        docToDelete: $docToDelete,
                        showDeleteDocConfirm: $showDeleteDocConfirm,
                        editMode: editMode
                    )
                    
                    if type != SynthesisStore.SynthesisType.allCases.last {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .wikiContainer(background: AnyView(Rectangle().fill(WikiUI.containerMaterial)))
        }
    }
    
    private var listHeader: some View {
        HStack {
            Text(L10n.Synthesis.tr("documentList")).font(.title3.bold())
            Spacer()
            editAndBatchDeleteControls
        }
        .padding(.vertical, 8)
        .foregroundStyle(.wikiText)
        .textCase(nil)
    }

    /**
     * @description: 渲染单个知识分组的 Header，支持展开/收起动画
     * @param {SynthesisType} type 分组类型
     * @param {Int} count 文档数量
     * @return {View}
     */
    private func typeGroupHeader(type: SynthesisStore.SynthesisType, count: Int) -> some View {
        Button {
            withAnimation {
                if expandedSynthesisSections.contains(type) {
                    expandedSynthesisSections.remove(type)
                } else {
                    expandedSynthesisSections.insert(type)
                }
            }
        } label: {
            HStack {
                Label(type.title, systemImage: type.icon)
                    .font(.subheadline.bold())
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.wikiAccent.opacity(0.1))
                        .foregroundStyle(.wikiAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(expandedSynthesisSections.contains(type) ? 90 : 0))
                    .foregroundStyle(.wikiSecondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var editAndBatchDeleteControls: some View {
        HStack(spacing: 8) {
            if editMode == .active {
                HStack(spacing: 12) {
                    // 批量删除按钮 (始终显示，无选中时禁用)
                    Button(action: {
                        HapticFeedback.shared.trigger(.warning)
                        showBatchDeleteConfirm = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text(L10n.Common.tr("delete"))
                        }
                        .font(.footnote.bold())
                        .foregroundStyle(selectedDocIDs.isEmpty ? .wikiSecondary.opacity(0.5) : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selectedDocIDs.isEmpty ? Color.clear : Color.red)
                        )
                        .overlay(
                            Capsule().stroke(selectedDocIDs.isEmpty ? Color.wikiBorder : Color.red, lineWidth: 1)
                        )
                    }
                    .disabled(selectedDocIDs.isEmpty)
                    
                    // 清空全部按钮
                    Button(action: {
                        HapticFeedback.shared.trigger(.warning)
                        showClearAllConfirm = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.slash")
                            Text(L10n.Common.tr("clearAll"))
                        }
                        .font(.footnote.bold())
                        .foregroundStyle(.wikiSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().stroke(Color.wikiBorder, lineWidth: 1)
                        )
                    }
                    .confirmationDialog(Localized.tr("synthesis.clearAllConfirm"), isPresented: $showClearAllConfirm, titleVisibility: .visible) {
                        Button(L10n.Common.tr("clearAll"), role: .destructive) {
                            synthesisStore.clearAll()
                            HapticFeedback.shared.trigger(.success)
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // 编辑/完成按钮
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if editMode == .inactive {
                        editMode = .active
                    } else {
                        editMode = .inactive
                        selectedDocIDs.removeAll()
                    }
                }
            }) {
                Text(editMode == .active ? L10n.Common.tr("done") : L10n.Common.tr("edit"))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.wikiAccent)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selection = nil }
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.wikiText)
                .frame(width: 32, height: 44) // 移除背景和形状，保留标准热区
        }
    }
    
    private func docRowContent(doc: SynthesisStore.SynthesisDocument, type: SynthesisStore.SynthesisType) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(type.formatColor.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: type.formatIcon).foregroundStyle(type.formatColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(Localized.trf("synthesis.generatedAt", formatDate(doc.createdAt)))
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            Spacer()
            
            if editMode == .inactive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.wikiSecondary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }

    private func batchDelete() {
        HapticFeedback.shared.trigger(.warning)
        synthesisStore.batchDeleteSynthesisDocs(ids: selectedDocIDs)
        selectedDocIDs.removeAll()
        editMode = .inactive
        HapticFeedback.shared.trigger(.success)
    }
    
    @ViewBuilder
    private var outputSheet: some View {
        NavigationStack {
            Group {
                if let doc = selectedDoc {
                    switch doc.type {
                    case .mindmap, .infographic:
                        VStack(spacing: WikiUI.standardPadding) {
                            if let title = extractTitle(from: doc.content) {
                                Text(title)
                                    .font(.title2.bold())
                                    .padding(.top, WikiUI.widePadding)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            
                            MermaidWebView(mermaidCode: extractMermaidCode(from: doc.content))
                                .id(doc.id)
                        }
                    case .quiz:
                        if let data = doc.content.data(using: .utf8),
                           let quiz = try? JSONDecoder().decode(QuizModel.self, from: data) {
                            QuizView(quiz: quiz)
                        } else {
                            fallbackView(doc: doc)
                        }
                    default:
                        fallbackView(doc: doc)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.tr("done")) { showOutput = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 18) {
                        Button {
                            if let doc = selectedDoc {
                                #if os(iOS)
                                UIPasteboard.general.string = doc.content
                                #endif
                                HapticFeedback.shared.trigger(.success)
                            }
                        } label: { Image(systemName: "doc.on.doc") }

                        Button { exportAction() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fallbackView(doc: SynthesisStore.SynthesisDocument) -> some View {
        ScrollView {
            MarkdownRendererView(content: doc.content, isPrivate: false, onLinkTap: { _ in })
                .padding()
        }
    }


    
    @State private var llmError: String?

    private func synthesisButton(type: SynthesisStore.SynthesisType) -> some View {
        SynthesisActionButton(type: type, 
                             store: store, 
                             showNoPagesAlert: $showNoPagesAlert, 
                             showLimitAlert: $showLimitAlert,
                             showLLMAlert: $showLLMAlert)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /**
     * @description: 触发文档导出流程：请求 SynthesisStore 生成物理文件并弹出预览
     * @return {*}
     */
    private func exportAction() {
        guard let doc = selectedDoc else { return }
        Task {
            do {
                let url = try await synthesisStore.exportSynthesisDocument(doc)
                await MainActor.run { 
                    self.pdfURL = IdentifiableURL(url: url)
                    HapticFeedback.shared.trigger(.success) 
                }
            } catch {
                await MainActor.run { 
                    self.exportError = error.localizedDescription
                    self.showExportError = true 
                }
            }
        }
    }

    /// 正在运行的任务区域
    @ViewBuilder
    private func runningTasksSection(tasks: [GlobalTask]) -> some View {
        VStack(alignment: .leading, spacing: WikiUI.medium) {
            runningTasksHeader
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    synthesisTaskRow(task: task)
                        .padding()
                    if task.id != tasks.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(WikiUI.containerMaterial)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                    .stroke(WikiUI.containerBorder.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }
    }

    /// 渲染任务状态行
    private func synthesisTaskRow(task: GlobalTask) -> some View {
        HStack(spacing: WikiUI.standardPadding) {
            ZStack {
                Circle().fill(Color.wikiAccent.opacity(0.1)).frame(width: WikiUI.Graph.selectedNodeSize, height: WikiUI.Graph.selectedNodeSize)
                ProgressView()
            }
            VStack(alignment: .leading, spacing: WikiUI.tiny * 1.5) {
                Text(task.name).font(.subheadline.weight(.semibold))
                if case .running(let progress) = task.status {
                    ProgressView(value: progress).tint(.wikiAccent)
                }
            }
        }
    }

    // MARK: - 核心视图组件
    
    /// 合成操作入口视图：展示各类型合成任务的启动按钮
    private var synthesisEntryView: some View {
        VStack(alignment: .leading, spacing: WikiUI.medium) {
            WikiSectionHeader(title: L10n.Synthesis.tr("actions"), icon: "wand.and.stars")
                .padding(.horizontal, 4)
            
            // 操作网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WikiUI.medium) {
                ForEach(SynthesisStore.SynthesisType.allCases) { type in
                    synthesisButton(type: type)
                }
            }
            .wikiContainer(padding: true)
        }
    }

    /// 正在运行的任务区域 Header
    private var runningTasksHeader: some View {
        Text(L10n.AI.Task.tr("status.running"))
            .font(.title3.bold())
            .foregroundStyle(.wikiAccent)
    }

    /**
     * @description: 从 Markdown 文本中尝试提取第一个一级标题作为文档名
     * @param {String} content 原始 Markdown 文本
     * @return {String?} 提取到的标题，若无则返回 nil
     */
    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        if let firstLine = lines.map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }),
           firstLine.hasPrefix("# ") {
            return firstLine.replacingOccurrences(of: "# ", with: "")
        }
        return nil
    }

    /**
     * @description: 提取文本中的 Mermaid 代码块内容，供渲染器使用
     * @param {String} content 包含 Markdown 代码块的文本
     * @return {String} 纯净的 Mermaid DSL 文本
     */
    private func extractMermaidCode(from content: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "```(?:mermaid)?\\n([\\s\\S]*?)```", options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let lines = content.components(separatedBy: .newlines)
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") && !trimmed.isEmpty
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatByteSize(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b < 1024 { return "\(bytes) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
        return String(format: "%.1f MB", b / (1024 * 1024))
    }
}

// MARK: - Synthesis Action Button
/// 合成操作启动按钮组件
/// 负责单个合成任务（如思维导图生成）的触发逻辑、前置校验、生成进度展示及超限状态控制
private struct SynthesisActionButton: View {
    let type: SynthesisStore.SynthesisType
    let store: KMStore
    @Environment(SynthesisStore.self) var synthesisStore
    
    @EnvironmentObject var llmService: LLMService
    @Binding var showNoPagesAlert: Bool
    @Binding var showLimitAlert: Bool
    @Binding var showLLMAlert: Bool
    
    var body: some View {
        let state = synthesisStore.synthesisStates[type] ?? .idle
        let currentCount = synthesisStore.synthesisResults[type]?.count ?? 0
        let isLimitReached = currentCount >= synthesisStore.maxSynthesisDocsPerType
        
        VStack(spacing: 8) {
            Button(action: { 
                HapticFeedback.shared.trigger(.selection)
                
                // Pre-check: LLM Config (Key, URL, Model)
                if !llmService.isReady {
                    HapticFeedback.shared.trigger(.error)
                    showLLMAlert = true
                    return
                }
                
                if store.pages.isEmpty {
                    HapticFeedback.shared.trigger(.error)
                    showNoPagesAlert = true
                    return
                }
                
                if isLimitReached {
                    HapticFeedback.shared.trigger(.error)
                    showLimitAlert = true
                    return
                }
                
                let combinedContent = store.pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
                synthesisStore.performSynthesis(type: type, combinedContent: combinedContent)
            }) {
                VStack(spacing: WikiUI.tightPadding * 0.75) {
                    ZStack {
                        Circle().fill(Color.wikiAccent.opacity(0.05)).frame(width: WikiUI.Graph.selectedNodeSize, height: WikiUI.Graph.selectedNodeSize)
                        Image(systemName: type.icon)
                            .font(.system(size: WikiUI.chipRadius))
                            .opacity((state == .generating || isLimitReached) ? 0.2 : 1.0)
                        
                        if state == .generating {
                            ProgressView()
                                .scaleEffect(1.0)
                                .tint(.wikiAccent)
                        } else if isLimitReached {
                            Image(systemName: "lock.fill")
                                .font(.system(size: WikiUI.subheadlineFontSize))
                                .foregroundStyle(.red.opacity(0.6))
                        }
                    }
                    Text(type.title).font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WikiUI.medium)
                .wikiCardStyle(cornerRadius: WikiUI.large)
                .foregroundStyle(isLimitReached ? .wikiSecondary : .wikiText)
            }
            .buttonStyle(SynthesisButtonStyle())
            .disabled(state == .generating || isLimitReached)
            .animation(.spring(response: 0.3), value: state)
            .animation(.spring(response: 0.3), value: isLimitReached)
            
            if isLimitReached {
                Text(Localized.tr("synthesis.limitReachedWarning"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Synthesis Type Section
/// 合成文档分组区域组件
/// 负责按类型展示已生成的文档列表，支持分组展开/折叠及批量编辑状态同步
private struct SynthesisTypeSection: View {
    let type: SynthesisStore.SynthesisType
    @Binding var expandedSections: Set<SynthesisStore.SynthesisType>
    @Binding var selectedDocIDs: Set<UUID>
    @Binding var selectedDoc: SynthesisStore.SynthesisDocument?
    @Binding var showOutput: Bool
    @Binding var docToRename: SynthesisStore.SynthesisDocument?
    @Binding var newDocName: String
    @Binding var showRenameDialog: Bool
    @Binding var docToDelete: SynthesisStore.SynthesisDocument?
    @Binding var showDeleteDocConfirm: Bool
    let editMode: EditMode
    
    @Environment(SynthesisStore.self) var synthesisStore
    
    var body: some View {
        let docs = synthesisStore.synthesisResults[type] ?? []
        
        Group {
            // 类型分组 Header
            Button {
                withAnimation {
                    if expandedSections.contains(type) {
                        expandedSections.remove(type)
                    } else {
                        expandedSections.insert(type)
                    }
                }
            } label: {
                HStack {
                    Label(type.title, systemImage: type.icon)
                        .font(.subheadline.bold())
                    Spacer()
                    if docs.count > 0 {
                        Text("\(docs.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.wikiAccent.opacity(0.1))
                            .foregroundStyle(.wikiAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(expandedSections.contains(type) ? 90 : 0))
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.wikiCard)
            .listRowSeparator(.hidden)
            .font(.subheadline.bold()) // 统一使用 subheadline 确保与主按钮一致
            
            if expandedSections.contains(type) {
                if docs.isEmpty {
                    Text(Localized.tr("synthesis.noDocs"))
                        .font(.caption.bold())
                        .foregroundStyle(.wikiSecondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                        .background(Color.wikiBackground.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 4)
                } else {
                    ForEach(docs) { doc in
                        SynthesisDocRow(
                            doc: doc,
                            type: type,
                            editMode: editMode,
                            isSelected: selectedDocIDs.contains(doc.id),
                            onTap: {
                                if editMode == .active {
                                    if selectedDocIDs.contains(doc.id) {
                                        selectedDocIDs.remove(doc.id)
                                    } else {
                                        selectedDocIDs.insert(doc.id)
                                    }
                                } else {
                                    selectedDoc = doc
                                    showOutput = true
                                }
                            },
                            onRename: {
                                docToRename = doc
                                newDocName = doc.name
                                showRenameDialog = true
                            },
                            onDelete: {
                                docToDelete = doc
                                showDeleteDocConfirm = true
                            }
                        )
                        
                        if doc.id != docs.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Synthesis Doc Row
/// 合成文档条目行组件
/// 负责展示单个生成文档的详情、预览入口及重命名/删除等交互操作
private struct SynthesisDocRow: View {
    let doc: SynthesisStore.SynthesisDocument
    let type: SynthesisStore.SynthesisType
    let editMode: EditMode
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @Environment(SynthesisStore.self) var synthesisStore

    init(doc: SynthesisStore.SynthesisDocument, 
         type: SynthesisStore.SynthesisType, 
         editMode: EditMode, 
         isSelected: Bool, 
         onTap: @escaping () -> Void, 
         onRename: @escaping () -> Void, 
         onDelete: @escaping () -> Void) {
        self.doc = doc
        self.type = type
        self.editMode = editMode
        self.isSelected = isSelected
        self.onTap = onTap
        self.onRename = onRename
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // ══ 固定宽度的选择指示器插槽 ══
            Group {
                if editMode == .active {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .wikiAccent : .wikiSecondary.opacity(0.4))
                        .onTapGesture {
                            HapticFeedback.shared.trigger(.selection)
                            onTap()
                        }
                }
            }
            .frame(width: editMode == .active ? 24 : 0)
            .clipped()
            
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(type.formatColor.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: type.formatIcon).foregroundStyle(type.formatColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.wikiText)
                
                HStack(spacing: 8) {
                    Text(formatDate(doc.createdAt))
                    Text("·")
                    Text(formatByteSize(doc.size))
                }
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
            }
            Spacer()
            
            if editMode == .inactive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.wikiSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .wikiCardStyle(cornerRadius: 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label(Localized.tr("tag.rename"), systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.Common.tr("delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - Helpers
private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}

private func formatByteSize(_ bytes: Int) -> String {
    let b = Double(bytes)
    if b < 1024 { return "\(bytes) B" }
    if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
    return String(format: "%.1f MB", b / (1024 * 1024))
}

private struct SynthesisButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

