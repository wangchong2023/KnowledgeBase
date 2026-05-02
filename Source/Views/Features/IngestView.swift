import SwiftUI
import UniformTypeIdentifiers

// MARK: - Activity Item Model
/// Single activity log entry for the ingest activity panel.
struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let status: ActivityStatus
    let timestamp: Date
    var associatedPageID: UUID? = nil
    
    enum ActivityStatus {
        case pending
        case processing
        case completed
        case failed
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .processing: return "arrow.triangle.2.circlepath"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .wikiSecondary
            case .processing: return .wikiAccent
            case .completed: return .green
            case .failed: return .red
            }
        }
    }
}

// MARK: - Ingest View (Refactored — Composed from Sub-components)
/// 知识导入视图，由 5 个子组件组成：
/// IngestHeroSection / IngestEntryCardsSection / IngestManualFormSection / SmartIngestPreview / IngestTipsSection
struct IngestView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var llmService: LLMService

    @State private var newTitle = ""
    @State private var newContent = ""
    @State private var newType: PageType = .source
    @State private var newCustomIcon: String? = nil
    @State private var newTags: [String] = []
    @State private var isIngesting = false
    @State private var ingestSuccess = false
    @State private var useSmartIngest = false
    @State private var smartResult: SmartIngestResult?
    @State private var showSmartPreview = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showIconPicker = false
    @State private var showManualForm = false
    @State private var manualFormTitle = Localized.tr("ingest.manualEntry")
    @State private var showOCRScan = false
    @State private var showURLImport = false
    @State private var newURL = ""
    @State private var useDeepScan = false
    @State private var isExtracting = false
    
    // File Import State
    @State private var showFileImporter = false

    // Voice Note State
    @State private var showVoiceNote = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    IngestHeroSection()

                    if isExtracting {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.wikiAccent)
                            Text(Localized.tr("ingest.processing"))
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color.wikiCard.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    IngestEntryCardsSection(
                        showManualForm: Binding(
                            get: { showManualForm },
                            set: { newValue in
                                if newValue { manualFormTitle = Localized.tr("ingest.manualEntry") }
                                showManualForm = newValue
                            }
                        ),
                        showOCRScan: $showOCRScan,
                        newType: $newType,
                        showFileImporter: $showFileImporter,
                        showVoiceNote: $showVoiceNote,
                        showURLImport: $showURLImport
                    )

                    // 导入活动状态展示区域（改为跳转到全局任务中心）
                    if !TaskCenter.shared.tasks.filter({ $0.type == .ingest }).isEmpty {
                        taskCenterLinkSection
                    }


                }
                .padding(.bottom, 40)
            }
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("ingest.title"))
            .alert(Localized.tr("ingest.error"), isPresented: $showError) {
                Button(Localized.tr("ingest.ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $newCustomIcon)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: {
                    var types: [UTType] = [.pdf, .plainText, .text]
                    if let doc = UTType("com.microsoft.word.doc") { types.append(doc) }
                    if let docx = UTType("org.openxmlformats.wordprocessingml.document") { types.append(docx) }
                    if let xls = UTType("com.microsoft.excel.xls") { types.append(xls) }
                    if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") { types.append(xlsx) }
                    if let md = UTType("net.daringfireball.markdown") { types.append(md) }
                    return types
                }(),
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showVoiceNote) {
                VoiceNoteView(onFinish: { title, content in
                    self.newTitle = title
                    self.newContent = content
                    self.manualFormTitle = Localized.tr("speech.title")
                    self.showManualForm = true
                })
            }
            .sheet(isPresented: $showOCRScan) {
                OCRScanView(onFinish: { title, content in
                    self.newTitle = title
                    self.newContent = content
                    self.manualFormTitle = Localized.tr("ocr.title")
                    self.showManualForm = true
                })
            }
            .sheet(isPresented: $showURLImport) {
                URLImportSheet(
                    urlText: $newURL,
                    onImport: { handleURLImport() }
                )
            }
            .sheet(isPresented: $showManualForm) {
                manualFormSheet
            }
            .onReceive(NotificationCenter.default.publisher(for: .importFromClipboard)) { _ in
                performClipboardImport()
            }
        }
    }

    private var manualFormSheet: some View {
        NavigationStack {
            ScrollView {
                IngestManualFormSection(
                    newTitle: $newTitle,
                    newContent: $newContent,
                    newType: $newType,
                    newCustomIcon: $newCustomIcon,
                    newTags: $newTags,
                    showIconPicker: $showIconPicker,
                    useSmartIngest: $useSmartIngest,
                    smartResult: $smartResult,
                    isIngesting: $isIngesting,
                    ingestSuccess: $ingestSuccess,
                    errorMessage: $errorMessage,
                    showError: $showError,
                    useDeepScan: $useDeepScan,
                    llmService: llmService,
                    store: store,
                    onPerformIngest: performIngest,
                    onConfirmSmartIngest: confirmSmartIngest
                )
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(manualFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localized.tr("misc.cancel")) {
                        showManualForm = false
                    }
                }
            }
        }
    }

    // MARK: - Task Center Link Section
    private var taskCenterLinkSection: some View {
        Button(action: { store.selectedTool = .taskCenter }) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.wikiAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localized.tr("ingest.queue.title"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Text(Localized.tr("ingest.queue.desc"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                Spacer()
                if TaskCenter.shared.unreadCount > 0 {
                    Text("\(TaskCenter.shared.unreadCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.red))
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Import Handler
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                // 安全校验：文件大小限制 (50MB)
                // 目的：防止大文件解析导致内存溢出或响应卡顿
                if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resources.fileSize {
                    let limit = 50 * 1024 * 1024 // 50MB 阈值
                    if fileSize > limit {
                        errorMessage = Localized.tr("ingest.fileTooLarge")
                        showError = true
                        continue
                    }
                }

                isExtracting = true
                // 预入库预览逻辑：仅提取文本，不直接写入 SQLite
                if let extracted = store.extractText(from: url) {
                    newTitle = extracted.title
                    newContent = extracted.content
                    manualFormTitle = Localized.tr("ingest.fileImport")
                    isExtracting = false
                    showManualForm = true
                    HapticManager.shared.trigger(.success)
                } else {
                    isExtracting = false
                    errorMessage = Localized.tr("ingest.error")
                    showError = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Ingest Logic
    private func performIngest() {
        let taskID = TaskCenter.shared.addTask(type: .ingest, name: Localized.tr("ingest.manualEntry"), target: newTitle)
        isIngesting = true
        ingestSuccess = false
        smartResult = nil

        if useSmartIngest && llmService.isEnabled {
            Task {
                do {
                    let result = try await llmService.smartIngest(
                        title: newTitle,
                        rawContent: newContent,
                        pages: store.pages
                    )
                    await MainActor.run {
                        smartResult = result
                        isIngesting = false
                        showSmartPreview = true
                        TaskCenter.shared.updateTask(taskID, status: .completed)
                    }
                } catch {
                    await MainActor.run {
                        isIngesting = false
                        errorMessage = error.localizedDescription
                        showError = true
                        TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                    }
                }
            }
        } else {
            let tags = newTags

            Task {
                do {
                    let page = try await store.ingestWithFolding(
                        title: newTitle,
                        content: newContent,
                        type: newType,
                        forceDeepScan: useDeepScan
                    )

                    await MainActor.run {
                        var updatedPage = page
                        updatedPage.tags = tags
                        updatedPage.customIcon = newCustomIcon
                        store.updatePage(updatedPage, forceDeepScan: false)

                        isIngesting = false
                        ingestSuccess = true
                        HapticManager.shared.trigger(.success)
                        
                        TaskCenter.shared.updateTask(taskID, status: .completed, associatedPageID: page.id)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            resetForm()
                        }
                    }
                } catch {
                    await MainActor.run {
                        isIngesting = false
                        errorMessage = error.localizedDescription
                        showError = true
                        TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
                    }
                }
            }
        }
    }

    private func confirmSmartIngest() {
        guard let result = smartResult else { return }
        
        Task {
            let type: PageType = PageType(rawValue: result.suggestedType) ?? newType

            let page = store.createPage(
                title: newTitle,
                type: type,
                customIcon: newCustomIcon,
                content: result.compiledContent,
                tags: result.suggestedTags
            )

            var updatedPage = page
            var relatedIDs: [UUID] = []
            for title in result.relatedTitles {
                if let linked = await store.pageByTitle(title) {
                    relatedIDs.append(linked.id)
                }
            }
            updatedPage.relatedPageIDs = relatedIDs
            
            await MainActor.run {
                store.updatePage(updatedPage, forceDeepScan: false)

                store.addLog(action: Localized.tr("logAction.smartIngest"), target: newTitle, details: Localized.trf("ingest.smartIngestDoneDesc", type.displayName))

                smartResult = nil
                ingestSuccess = true
                HapticManager.shared.trigger(.success)

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    resetForm()
                }
            }
        }
    }

    private func resetForm() {
        newTitle = ""
        newContent = ""
        newTags = []
        newCustomIcon = nil
        ingestSuccess = false
    }



    // MARK: - URL Import Handler
    private func handleURLImport() {
        let urls = newURL.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard let firstURL = urls.first else { return }
        
        // 清空输入并关闭 Sheet
        newURL = ""
        showURLImport = false
        isExtracting = true
        
        Task {
            do {
                let extracted = try await store.fetchURLContent(urlString: firstURL)
                await MainActor.run {
                    self.newTitle = extracted.title
                    self.newContent = extracted.content
                    self.manualFormTitle = Localized.tr("ingest.urlImport")
                    self.isExtracting = false
                    self.showManualForm = true
                    HapticManager.shared.trigger(.success)
                }
            } catch {
                await MainActor.run {
                    self.isExtracting = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    // MARK: - Clipboard Import
    private func performClipboardImport() {
        guard let clipboardContent = WikiPasteboard.string, !clipboardContent.isEmpty else {
            errorMessage = Localized.tr("ingest.clipboardEmpty")
            showError = true
            return
        }

        // 解析剪贴板内容
        let lines = clipboardContent.components(separatedBy: "\n")
        var title = ""
        let content = clipboardContent

        if let firstLine = lines.first {
            title = firstLine
                .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        if title.isEmpty {
            title = Localized.tr("settings.importedPageTitle")
        }

        // 填充到表单并显示
        newTitle = title
        newContent = content
        newType = .concept
        newTags = [Localized.tr("settings.importTag")]
        manualFormTitle = Localized.tr("ingest.clipboardImport") // 使用 "剪贴板" 或新增 "从剪贴板导入"
        
        withAnimation {
            showManualForm = true
        }
    }
}

// MARK: - Activity Row View
struct ActivityRow: View {
    @EnvironmentObject var store: KMStore
    let item: ActivityItem
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.status.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                if item.status == .processing {
                    Image(systemName: item.status.icon)
                        .font(.caption)
                        .foregroundStyle(item.status.color)
                        .rotationEffect(.degrees(isCurrent ? 360 : 0))
                        .animation(
                            isCurrent ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isCurrent
                        )
                } else {
                    Image(systemName: item.status.icon)
                        .font(.caption)
                        .foregroundStyle(item.status.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.wikiText)
                    .lineLimit(1)
                
                Text(item.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Spacer()
            
            if let pageID = item.associatedPageID {
                Button(action: {
                    withAnimation {
                        store.selectedPageID = pageID
                    }
                }) {
                    Text(Localized.tr("misc.view"))
                        .font(.caption2.bold())
                        .foregroundStyle(.wikiAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.wikiAccent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrent ? item.status.color.opacity(0.1) : Color.wikiCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
    }
}
