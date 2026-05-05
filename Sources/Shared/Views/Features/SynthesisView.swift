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
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Synthesis View
/// 知识合成视图入口
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
        
        return List {
            // 合成入口
            Section {
                VStack(alignment: .leading, spacing: WikiUI.tightPadding) {
                    Text(Localized.tr("synthesis.actions"))
                        .font(.subheadline.bold())
                        .foregroundStyle(.wikiSecondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WikiUI.medium) {
                        ForEach(SynthesisStore.SynthesisType.allCases) { type in
                            synthesisButton(type: type)
                        }
                    }
                }
                .padding(.vertical, WikiUI.tiny)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            
            // 进行中的任务
            if !runningTasks.isEmpty {
                Section {
                    ForEach(runningTasks) { task in
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
                } header: {
                    Text(L10n.AI.Task.tr("status.running")).font(.subheadline.bold()).foregroundStyle(.wikiAccent)
                }
                .listRowBackground(Color.wikiCard.opacity(0.5))
            }
            
            // 文档列表
            Section(header: listHeader) {
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
                        editMode: editMode
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.wikiBackground)
        .environment(\.editMode, $editMode)
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
        .alert(Localized.tr("synthesis.error.noPages"), isPresented: $showNoPagesAlert) {
            Button(L10n.Common.tr("ok"), role: .cancel) { }
        }
        .alert(Localized.tr("synthesis.error.limitReached"), isPresented: $showLimitAlert) {
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
        .confirmationDialog(Localized.tr("synthesis.clearAllConfirm"), isPresented: $showClearAllConfirm, titleVisibility: .visible) {
            Button(L10n.Common.tr("clearAll"), role: .destructive) {
                synthesisStore.clearAll()
                HapticFeedback.shared.trigger(.success)
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) { }
        }
        .confirmationDialog(Localized.tr("synthesis.batchDeleteConfirm"), isPresented: $showBatchDeleteConfirm, titleVisibility: .visible) {
            Button(L10n.Common.tr("delete"), role: .destructive) {
                batchDelete()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) { }
        }
    }
    
    private var listHeader: some View {
        HStack {
            Text(Localized.tr("synthesis.documentList")).font(.title3.bold())
            Spacer()
            editAndBatchDeleteControls
        }
        .padding(.vertical, 8)
        .foregroundStyle(.wikiText)
        .textCase(nil)
    }

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
                        .clipShape(Capsule())
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
        HStack(spacing: 10) {
            if editMode == .active && !selectedDocIDs.isEmpty {
                Button(role: .destructive) { 
                    HapticFeedback.shared.trigger(.warning)
                    showBatchDeleteConfirm = true
                } label: { 
                    Text(L10n.Common.tr("delete"))
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.red.gradient))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if editMode == .inactive {
                Button(action: {
                    HapticFeedback.shared.trigger(.warning)
                    showClearAllConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(Circle().fill(Color.red.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

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
                    .font(.footnote.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(editMode == .active ? Color.wikiAccent : Color.wikiAccent.opacity(0.1))
                    )
                    .foregroundStyle(editMode == .active ? .white : Color.wikiAccent)
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
                .frame(width: 44, height: 44).background(.ultraThinMaterial)
                .clipShape(Circle()).shadow(color: .black.opacity(0.1), radius: 4)
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
                            // 提取并显示内部标题
                            let lines = doc.content.components(separatedBy: .newlines)
                            if let firstLine = lines.map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }),
                               firstLine.hasPrefix("# ") {
                                Text(firstLine.replacingOccurrences(of: "# ", with: ""))
                                    .font(.title2.bold())
                                    .padding(.top, WikiUI.widePadding)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .center) // 居中对齐
                            }
                            
                            // 过滤掉标题行，只把 Mermaid 代码传给 Webview
                            let pureMermaid = lines
                                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }
                                .joined(separator: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                            MermaidWebView(mermaidCode: pureMermaid)
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


    
    @State private var showLLMAlert = false
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
}

// MARK: - Synthesis Action Button
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
                    Text(type.title).font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WikiUI.medium)
                .background(RoundedRectangle(cornerRadius: WikiUI.large).fill(Color.wikiCard.opacity(isLimitReached ? 0.4 : 0.8)))
                .foregroundStyle(isLimitReached ? .wikiSecondary : .wikiAccent)
                .overlay(RoundedRectangle(cornerRadius: WikiUI.large).stroke(isLimitReached ? Color.red.opacity(0.2) : Color.wikiAccent.opacity(0.1), lineWidth: 1))
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
private struct SynthesisTypeSection: View {
    let type: SynthesisStore.SynthesisType
    @Binding var expandedSections: Set<SynthesisStore.SynthesisType>
    @Binding var selectedDocIDs: Set<UUID>
    @Binding var selectedDoc: SynthesisStore.SynthesisDocument?
    @Binding var showOutput: Bool
    @Binding var docToRename: SynthesisStore.SynthesisDocument?
    @Binding var newDocName: String
    @Binding var showRenameDialog: Bool
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
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(expandedSections.contains(type) ? 90 : 0))
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.wikiCard)
            .listRowSeparator(.hidden)
            
            if expandedSections.contains(type) {
                if docs.isEmpty {
                    Text(Localized.tr("synthesis.noDocs"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .listRowBackground(Color.wikiCard)
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
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Synthesis Doc Row
private struct SynthesisDocRow: View {
    let doc: SynthesisStore.SynthesisDocument
    let type: SynthesisStore.SynthesisType
    let editMode: EditMode
    let isSelected: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    
    @Environment(SynthesisStore.self) var synthesisStore
    
    var body: some View {
        HStack(spacing: 12) {
            // ══ 固定宽度的选择指示器插槽 ══
            // 使用 Group + frame 确保无论是否显示指示器，后续内容的 X 坐标保持固定，从而实现“不挪动”
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
            .frame(width: editMode == .active ? 24 : 0) // 在非编辑模式下宽度为 0
            .clipped()
            .animation(.spring(response: 0.3), value: editMode)

            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(type.formatColor.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: type.formatIcon).foregroundStyle(type.formatColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.wikiText)
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
        .padding(.vertical, 4)
        .listRowBackground(Color.wikiCard)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 删除功能
            Button(role: .destructive) {
                HapticFeedback.shared.trigger(.warning)
                synthesisStore.deleteSynthesisDoc(type: type, docID: doc.id)
            } label: {
                Label(L10n.Common.tr("delete"), systemImage: "trash")
            }
            
            // 重命名功能
            Button {
                onRename()
            } label: {
                Label(Localized.tr("tag.rename"), systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
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

