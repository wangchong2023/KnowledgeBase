import SwiftUI

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
    @State private var newTags = ""
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
    @State private var useDeepScan = true
    
    // Activity Log State
    @State private var activityLog: [ActivityItem] = []
    @State private var currentActivityID: UUID?

    // File Import State
    @State private var showFileImporter = false

    // Voice Note State
    @State private var showVoiceNote = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    IngestHeroSection()

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

                    // 导入活动状态展示区域（内联显示，避免遮挡）
                    if !activityLog.isEmpty {
                        inlineActivitySection
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
                allowedContentTypes: [.pdf, .text, .plainText, .xml],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showVoiceNote) {
                VoiceNoteView()
            }
            .sheet(isPresented: $showOCRScan) {
                OCRScanView()
            }
            .alert("URL 导入", isPresented: $showURLImport) {
                TextField("https://...", text: $newURL)
                    .textInputAutocapitalization(.never)
                Button("导入") {
                    handleURLImport()
                }
                Button("取消", role: .cancel) { newURL = "" }
            } message: {
                Text("输入网页或 YouTube 链接，AI 将自动提取并编译知识。")
            }
            .sheet(isPresented: $showManualForm) {
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
                            llmService: llmService,
                            store: store,
                            onPerformIngest: performIngest,
                            onConfirmSmartIngest: confirmSmartIngest,
                            useDeepScan: $useDeepScan
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
            .onReceive(NotificationCenter.default.publisher(for: .importFromClipboard)) { _ in
                performClipboardImport()
            }
        }
    }

    // MARK: - Inline Activity Section
    private var inlineActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.wikiText)
                Text(Localized.tr("ingest.activity")) // 将通过多语言文件更新为"导入任务状态"
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Spacer()
                if !activityLog.isEmpty {
                    Button(action: {
                        withAnimation { activityLog.removeAll() }
                    }) {
                        Text(Localized.tr("misc.clear"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(activityLog.reversed()) { item in
                    ActivityRow(item: item, isCurrent: item.id == currentActivityID)
                        .padding(.horizontal)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - File Import Handler
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let activityID = UUID()
                let fileName = url.deletingPathExtension().lastPathComponent
                activityLog.append(ActivityItem(title: fileName, status: .processing, timestamp: Date()))
                currentActivityID = activityID

                // Use IngestService to process the file
                if let page = store.ingestDocument(at: url) {
                    // Update to completed
                    if let index = activityLog.firstIndex(where: { $0.id == activityID }) {
                        let title = useDeepScan ? "\(page.title) (RAG)" : page.title
                        activityLog[index] = ActivityItem(title: title, status: .completed, timestamp: Date(), associatedPageID: page.id)
                    }
                    HapticManager.success()
                } else {
                    // Update to failed
                    if let index = activityLog.firstIndex(where: { $0.id == activityID }) {
                        activityLog[index] = ActivityItem(title: fileName, status: .failed, timestamp: Date())
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Ingest Logic
    private func performIngest() {
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
                    }
                } catch {
                    await MainActor.run {
                        isIngesting = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        } else {
            let tags = newTags.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

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
                        store.updatePage(updatedPage)

                        isIngesting = false
                        ingestSuccess = true
                        HapticManager.success()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            resetForm()
                        }
                    }
                } catch {
                    await MainActor.run {
                        isIngesting = false
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func confirmSmartIngest() {
        guard let result = smartResult else { return }

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
            if let linked = store.pageByTitle(title) {
                relatedIDs.append(linked.id)
            }
        }
        updatedPage.relatedPageIDs = relatedIDs
        store.updatePage(updatedPage)

        store.addLog(action: Localized.tr("logAction.smartIngest"), target: newTitle, details: Localized.trf("ingest.smartIngestDoneDesc", type.displayName))

        smartResult = nil
        ingestSuccess = true
        HapticManager.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            resetForm()
        }
    }

    private func resetForm() {
        newTitle = ""
        newContent = ""
        newTags = ""
        newCustomIcon = nil
        ingestSuccess = false
    }



    // MARK: - URL Import Handler
    private func handleURLImport() {
        let urlString = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }
        
        let activityID = UUID()
        let statusTitle = useDeepScan ? "正在抓取并 RAG 索引..." : "正在抓取 URL..."
        activityLog.append(ActivityItem(title: statusTitle, status: .processing, timestamp: Date()))
        currentActivityID = activityID
        
        Task {
            do {
                let page = try await store.ingestURL(urlString, forceDeepScan: useDeepScan)
                await MainActor.run {
                    if let index = activityLog.firstIndex(where: { $0.id == activityID }) {
                        let title = useDeepScan ? "\(page.title) (RAG)" : page.title
                        activityLog[index] = ActivityItem(title: title, status: .completed, timestamp: Date(), associatedPageID: page.id)
                    }
                    newURL = ""
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    if let index = activityLog.firstIndex(where: { $0.id == activityID }) {
                        activityLog[index] = ActivityItem(title: "URL 抓取失败", status: .failed, timestamp: Date())
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                    newURL = ""
                }
            }
        }
    }

    // MARK: - Clipboard Import
    private func performClipboardImport() {
        guard let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty else {
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
        newTags = Localized.tr("settings.importTag")
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
                    Text("查看")
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
