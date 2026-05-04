@preconcurrency import SwiftUI
import WebKit

@MainActor
struct NavigationView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    var heroNamespace: Namespace.ID
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selection: SidebarSelection? = nil
    @State private var renderNonce = UUID() // 强制重绘标记 (Platinum Experience Item #5)
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace, selection: $selection)
        } detail: {
            DetailContentView(selection: $selection, selectedTab: $selectedTab)
                .id("\(String(describing: selection))-\(renderNonce.uuidString)")
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            print("🔍 [NAV-DIAG] NavigationView onAppear. selection: \(String(describing: selection))")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("splashDismissed"))) { _ in
            print("🔍 [NAV-DIAG] NavigationView received splashDismissed. No forced selection — Wiki tab is home.")
            store.navigationPath = NavigationPath()
            renderNonce = UUID()
        }
        .onChange(of: selection) { old, new in
            print("🔍 [NAV-DIAG] NavigationView selection changed: \(String(describing: old)) -> \(String(describing: new))")
        }
    }
}

// MARK: - Detail Content Wrapper
struct DetailContentView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: ContentView.AppTab
    @Environment(KMStore.self) var store
    
    var body: some View {
        @Bindable var localStore = store
        let currentStore = store
        let _ = print("🔍 [NAV-DIAG] DetailContentView rendering. Selection: \(String(describing: selection)), Path Count: \(localStore.navigationPath.count)")
        
        NavigationStack(path: $localStore.navigationPath) {
            destinationView(for: selection)
            .navigationDestination(for: WikiPage.self) { page in
                PageDetailView(page: page)
                    .environment(\.navigate, NavigateAction { target in
                        Task { @MainActor in
                            currentStore.navigationPath.append(target)
                        }
                    })
            }
            .environment(\.navigate, NavigateAction { target in
                Task { @MainActor in
                    currentStore.navigationPath.append(target)
                }
            })
        }
    }

    /// 根据 SidebarSelection 路由到对应视图
    @ViewBuilder
    private func destinationView(for selection: SidebarSelection?) -> some View {
        let _ = print("🔍 [NAV-DIAG] destinationView picking for: \(String(describing: selection))")
        switch selection {
        case .tool(.dashboard):
            KnowledgeDashboardView()
        case .none:
            wikiLandingView
        case .tool(.index):
            IndexView()
        case .filteredIndex(let type):
            IndexView(filterType: type)
        case .tool(.lint):
            LintView(selection: $selection)
        case .tool(.taskCenter):
            TaskCenterView()
        case .tool(.tagCloud):
            TagCloudView()
        case .tool(.pluginMarket):
            Text(Localized.tr("sidebar.pluginMarket"))
                .foregroundStyle(.wikiSecondary)
        case .tool(.synthesis):
            SynthesisView(selection: $selection, selectedTab: $selectedTab)
        case .tool(.chat):
            ChatViewContent(selectedTab: $selectedTab)
        case .tool(.weeklyReport):
            WeeklyReportView()
        case .tool(.log):
            LogView()
        case .tool(.collab):
            CollaborationView()
        case .page(let id):
            if let page = store.pages.first(where: { $0.id == id }) {
                PageDetailView(page: page)
            } else {
                ContentUnavailableView("Page not found", systemImage: "doc.questionmark")
            }
        }
    }

    private var wikiLandingView: some View {
        ContentUnavailableView(
            Localized.tr("sidebar.title"),
            systemImage: "books.vertical.fill",
            description: Text(Localized.tr("sidebar.allPages"))
        )
    }
}

// MARK: - Synthesis View
struct SynthesisView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: ContentView.AppTab
    @Environment(KMStore.self) var store
    @ObservedObject var taskCenter = TaskCenter.shared
    @State private var showOutput = false
    @State private var outputType: KMStore.SynthesisType = .mindmap
    @State private var selectedDoc: KMStore.SynthesisDocument?
    @State private var pdfURL: IdentifiableURL?

    @State private var exportError: String?
    @State private var showExportError = false
    @State private var docToRename: KMStore.SynthesisDocument?
    @State private var newDocName = ""
    @State private var docToDelete: KMStore.SynthesisDocument?
    @State private var showDeleteDocConfirm = false
    @State private var showRenameDialog = false
    
    @State private var editMode: EditMode = .inactive
    @State private var selectedDocIDs = Set<UUID>()
    @State private var showLimitAlert = false
    @State private var expandedSynthesisSections: Set<KMStore.SynthesisType> = Set(KMStore.SynthesisType.allCases)
    
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
                    ForEach(KMStore.SynthesisType.allCases) { type in
                        synthesisButton(type: type)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(Localized.tr("synthesis.actions")).font(.subheadline.bold()).foregroundStyle(.wikiSecondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            // 移除这里的禁用限制，允许用户在任何时候点击（点击后再提示）
            
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
                    Text(Localized.tr("aitask.status.running")).font(.subheadline.bold()).foregroundStyle(.wikiAccent)
                }
            }
            
            // 文档列表
            Section {
                ForEach(KMStore.SynthesisType.allCases) { type in
                    let docs = store.synthesisResults[type] ?? []
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
                                    Button(role: .destructive) { store.deleteSynthesisDoc(type: type, docID: doc.id) }
                                    label: { Label(Localized.tr("misc.delete"), systemImage: "trash") }
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
            Button(Localized.tr("misc.ok"), role: .cancel) { }
        }
        .alert(Localized.tr("synthesis.error.limitReached"), isPresented: $showLimitAlert) {
            Button(Localized.tr("misc.done"), role: .cancel) { }
        }
        .alert(Localized.tr("tag.rename"), isPresented: $showRenameDialog) {
             TextField(Localized.tr("tags.inputName"), text: $newDocName)
             Button(Localized.tr("tag.rename")) {
                 if let doc = docToRename {
                     store.renameSynthesisDoc(type: doc.type, docID: doc.id, newName: newDocName)
                 }
             }
             Button(Localized.tr("misc.cancel"), role: .cancel) { }
        }
    }
    
    private var editAndBatchDeleteControls: some View {
        HStack(spacing: 8) {
            if editMode == .active && !selectedDocIDs.isEmpty {
                Button(role: .destructive) { batchDelete() }
                label: { Text(Localized.tr("misc.delete")).fontWeight(.bold) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.red)
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    editMode = (editMode == .active) ? .inactive : .active
                    if editMode == .inactive { selectedDocIDs.removeAll() }
                }
            }) {
                Text(editMode == .active ? Localized.tr("misc.done") : Localized.tr("misc.edit"))
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
    private func docRowContent(doc: KMStore.SynthesisDocument, type: KMStore.SynthesisType) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.fromModelColorName(type.formatColorName).opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: type.formatIcon).foregroundStyle(Color.fromModelColorName(type.formatColorName))
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
        store.batchDeleteSynthesisDocs(ids: selectedDocIDs)
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
                    Button(Localized.tr("misc.done")) { showOutput = false }
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

    @State private var showNoPagesAlert = false
    
    private func synthesisButton(type: KMStore.SynthesisType) -> some View {
        let state = store.synthesisStates[type] ?? .idle
        // 统一底色：即使没有结果也使用 wikiCard 透明背景，保持视觉一致性
        return Button(action: { 
            HapticManager.shared.trigger(.selection)
            
            // 1. 数据空检查
            if store.pages.isEmpty {
                HapticManager.shared.trigger(.error)
                showNoPagesAlert = true
                return
            }
            
            // 2. 数量上限检查
            if (store.synthesisResults[type]?.count ?? 0) >= store.maxSynthesisDocsPerType {
                HapticManager.shared.trigger(.error)
                showLimitAlert = true
                return
            }
            
            store.performSynthesis(type: type) 
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
                let url: URL
                switch doc.type {
                case .slides:
                    url = try await WebViewExportService.shared.exportToPPTX(markdown: doc.content, fileName: doc.type.title)
                case .mindmap:
                    url = try await WebViewExportService.shared.exportMindmapToPDF(mermaidCode: doc.content, fileName: doc.type.title)
                default:
                    url = try await WebViewExportService.shared.exportToPDF(markdown: doc.content, fileName: doc.type.title)
                }
                await MainActor.run { self.pdfURL = IdentifiableURL(url: url); HapticManager.shared.trigger(.success) }
            } catch {
                await MainActor.run { self.exportError = error.localizedDescription; self.showExportError = true }
            }
        }
    }
}
