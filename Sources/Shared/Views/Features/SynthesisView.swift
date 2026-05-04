// SynthesisView.swift
//
// 作者: Wang Chong
// 功能说明: 知识合成视图，支持生成思维导图、测验、幻灯片、报告和信息图。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Synthesis View
/// 知识合成视图，支持生成思维导图、测验、幻灯片、报告和信息图。
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

    private func performSynthesis(type: SynthesisStore.SynthesisType) {
        let combinedContent = store.pages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        synthesisStore.performSynthesis(type: type, combinedContent: combinedContent)
    }
    
    var body: some View {
        let runningTasks = taskCenter.tasks.filter { task in
            guard task.type == .synthesis else { return false }
            if case .running = task.status { return true }
            return false
        }
        
        return List(selection: $selectedDocIDs) {
            // 合成入口
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(SynthesisStore.SynthesisType.allCases) { type in
                        synthesisButton(type: type)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(Localized.tr("synthesis.actions")).font(.subheadline.bold()).foregroundStyle(.wikiSecondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // 进行中的任务
            if !runningTasks.isEmpty {
                Section {
                    ForEach(runningTasks) { task in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(Color.wikiAccent.opacity(0.1)).frame(width: 40, height: 40)
                                ProgressView()
                            }
                            VStack(alignment: .leading, spacing: 6) {
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
            }
            
            // 文档列表
            Section {
                ForEach(SynthesisStore.SynthesisType.allCases) { type in
                    let docs = synthesisStore.synthesisResults[type] ?? []
                    DisclosureGroup(isExpanded: Binding(
                        get: { expandedSynthesisSections.contains(type) },
                        set: { isExpanded in
                            if isExpanded { expandedSynthesisSections.insert(type) }
                            else { expandedSynthesisSections.remove(type) }
                        }
                    )) {
                        if docs.isEmpty {
                            Text(Localized.tr("synthesis.noDocs"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(docs) { doc in
                                Group {
                                    if editMode == .active {
                                        docRowContent(doc: doc, type: type)
                                    } else {
                                        Button {
                                            selectedDoc = doc
                                            showOutput = true
                                        } label: {
                                            docRowContent(doc: doc, type: type)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .tag(doc.id)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { synthesisStore.deleteSynthesisDoc(type: type, docID: doc.id) }
                                    label: { Label(L10n.Common.tr("delete"), systemImage: "trash") }
                                }
                            }
                        }
                    } label: {
                        Label(type.title, systemImage: type.icon).font(.subheadline.bold())
                    }
                }
            } header: {
                HStack(spacing: 12) {
                    Text(Localized.tr("synthesis.documentList")).font(.title3.bold())
                    Spacer()
                    editAndBatchDeleteControls
                }
                .padding(.top, 24)
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.insetGrouped)
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
    }
    
    private var editAndBatchDeleteControls: some View {
        HStack(spacing: 8) {
            if editMode == .active && !selectedDocIDs.isEmpty {
                Button(role: .destructive) { batchDelete() }
                label: { Text(L10n.Common.tr("delete")).fontWeight(.bold) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.red)
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    editMode = (editMode == .active) ? .inactive : .active
                    if editMode == .inactive { selectedDocIDs.removeAll() }
                }
            }) {
                Text(editMode == .active ? L10n.Common.tr("done") : L10n.Common.tr("edit"))
                    .font(.subheadline.bold())
                    .foregroundStyle(editMode == .active ? .green : .wikiAccent)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(editMode == .active ? Color.green.opacity(0.1) : Color.wikiAccent.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selection = nil }
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.wikiText)
                .frame(width: 44, height: 44).background(.ultraThinMaterial)
                .clipShape(Circle()).shadow(color: .black.opacity(0.1), radius: 4)
        }
    }
    
    @ViewBuilder
    private func docRowContent(doc: SynthesisStore.SynthesisDocument, type: SynthesisStore.SynthesisType) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(type.formatColor.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: type.formatIcon).foregroundStyle(type.formatColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name).font(.subheadline.weight(.semibold))
                Text(Localized.trf("synthesis.generatedAt", formatDate(doc.createdAt))).font(.caption2).foregroundStyle(.wikiSecondary)
            }
            Spacer()
            if editMode == .inactive {
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.wikiSecondary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }

    private func batchDelete() {
        HapticManager.shared.trigger(.warning)
        synthesisStore.batchDeleteSynthesisDocs(ids: selectedDocIDs)
        selectedDocIDs.removeAll()
        editMode = .inactive
        HapticManager.shared.trigger(.success)
    }
    
    @ViewBuilder
    private var outputSheet: some View {
        NavigationStack {
            Group {
                if let doc = selectedDoc {
                    if doc.type == .mindmap {
                        MermaidWebView(mermaidCode: doc.content)
                            .id(doc.id)
                    } else if doc.type == .quiz, 
                              let data = doc.content.data(using: .utf8),
                              let quiz = try? JSONDecoder().decode(QuizModel.self, from: data) {
                        QuizView(quiz: quiz)
                    } else {
                        ScrollView {
                            MarkdownRendererView(content: doc.content, isPrivate: false, onLinkTap: { _ in })
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(selectedDoc?.type.title ?? "")
            .navigationBarTitleDisplayMode(.large)
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
                                HapticManager.shared.trigger(.success)
                            }
                        } label: { Image(systemName: "doc.on.doc") }

                        Button { exportAction() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }


    
    private func synthesisButton(type: SynthesisStore.SynthesisType) -> some View {
        let state = synthesisStore.synthesisStates[type] ?? .idle
        return Button(action: { 
            HapticManager.shared.trigger(.selection)
            
            if store.pages.isEmpty {
                HapticManager.shared.trigger(.error)
                showNoPagesAlert = true
                return
            }
            
            if (synthesisStore.synthesisResults[type]?.count ?? 0) >= synthesisStore.maxSynthesisDocsPerType {
                HapticManager.shared.trigger(.error)
                showLimitAlert = true
                return
            }
            
            performSynthesis(type: type) 
        }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.wikiAccent.opacity(0.05)).frame(width: 56, height: 56)
                    Image(systemName: type.icon).font(.system(size: 28)).opacity(state == .generating ? 0.2 : 1.0)
                    if state == .generating { ProgressView().scaleEffect(1.2) }
                }
                Text(type.title).font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.wikiCard.opacity(0.8)))
            .foregroundStyle(.wikiAccent)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.wikiAccent.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                    HapticManager.shared.trigger(.success) 
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
