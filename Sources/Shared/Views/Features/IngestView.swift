// IngestView.swift
//
// 作者: Wang Chong
// 功能说明: Single activity log entry for the ingest activity panel.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI
import UniformTypeIdentifiers

// MARK: - Activity Item Model
/// Single activity log entry for the ingest activity panel.
@MainActor
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
    @Environment(KMStore.self) var store
    @Environment(IngestStore.self) var ingestStore
    @Environment(AppRouter.self) var router
    @EnvironmentObject var llmService: LLMService
    @Binding var selectedTab: AppTab

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
    @State private var manualFormTitle = L10n.Ingest.tr("manualEntry")
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
        @Bindable var router = router
        ScrollView {
            VStack(spacing: 20) {
                IngestHeroSection()

                IngestEntryCardsSection(
                    showManualForm: Binding(
                        get: { showManualForm },
                        set: { newValue in
                            if newValue { manualFormTitle = L10n.Ingest.tr("manualEntry") }
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
                
                // 最近处理的文档列表
                recentActivitiesSection
            }
            .padding(.bottom, 40)
        }
        .background(Color.wikiBackground)
        .navigationTitle(L10n.Ingest.title)
        .alert(L10n.Ingest.tr("error"), isPresented: $showError) {
            Button(L10n.Ingest.tr("ok")) { errorMessage = nil }
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
        .navigationDestination(for: AppRoute.self) { route in
            ViewFactory.makeView(for: route)
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
                    ingestStore: ingestStore,
                    onPerformIngest: performIngest,
                    onConfirmSmartIngest: confirmSmartIngest
                )
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(manualFormTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("cancel")) {
                        showManualForm = false
                    }
                }
            }
        }
    }

    // MARK: - Task Center Link Section
    private var taskCenterLinkSection: some View {
        Button(action: { router.navigate(to: .taskCenter) }) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.wikiAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Ingest.tr("queue.title"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Text(L10n.Ingest.tr("queue.desc"))
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
                do {
                    isExtracting = true
                    let extracted = try ingestStore.handleFileUpload(at: url)
                    newTitle = extracted.title
                    newContent = extracted.content
                    manualFormTitle = L10n.Ingest.tr("fileImport")
                    isExtracting = false
                    showManualForm = true
                    HapticManager.shared.trigger(.success)
                } catch {
                    isExtracting = false
                    errorMessage = error.localizedDescription
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
        isIngesting = true
        ingestSuccess = false
        smartResult = nil

        Task {
            do {
                _ = try await ingestStore.performIngest(
                    title: newTitle,
                    content: newContent,
                    type: newType,
                    tags: newTags,
                    customIcon: newCustomIcon,
                    useSmart: useSmartIngest,
                    useDeepScan: useDeepScan
                )

                await MainActor.run {
                    isIngesting = false
                    ingestSuccess = true
                    
                    // 如果是智能摄入，可能需要预览（如果逻辑上有预览需求，此处可调整）
                    // 目前 KMStore.performIngest 已经处理了智能摄入的保存
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        resetForm()
                        showManualForm = false
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

    private func confirmSmartIngest() {
        guard let result = smartResult else { return }
        
        Task {
            _ = await ingestStore.finalizeSmartIngest(
                title: newTitle, 
                result: result, 
                customIcon: newCustomIcon
            )
            
            await MainActor.run {
                smartResult = nil
                ingestSuccess = true
                ToastManager.shared.show(type: .success, message: Localized.tr("ingest.success"))

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

    // MARK: - Recent Activities Section
    private var recentActivitiesSection: some View {
        let recentTasks = TaskCenter.shared.tasks
            .filter { $0.type == .ingest }
            .prefix(5)
        
        return Group {
            if !recentTasks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.Ingest.tr("recentActivities"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(recentTasks) { task in
                            ActivityRow(item: ActivityItem(
                                title: task.target.isEmpty ? task.name : task.target,
                                status: mapTaskStatus(task.status),
                                timestamp: task.startTime,
                                associatedPageID: task.associatedPageID
                            ), isCurrent: false, selectedTab: $selectedTab)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func mapTaskStatus(_ status: TaskStatus) -> ActivityItem.ActivityStatus {
        switch status {
        case .pending: return .pending
        case .running: return .processing
        case .completed: return .completed
        case .failed: return .failed
        }
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
        ToastManager.shared.show(type: .processing, message: L10n.Ingest.tr("processing"), duration: 0)
        
        Task {
            do {
                let extracted = try await ingestStore.fetchURLContent(urlString: firstURL)
                await MainActor.run {
                    self.newTitle = extracted.title
                    self.newContent = extracted.content
                    self.manualFormTitle = L10n.Ingest.tr("urlImport")
                    self.isExtracting = false
                    ToastManager.shared.dismiss()
                    self.showManualForm = true
                    ToastManager.shared.show(type: .success, message: L10n.Ingest.tr("success"))
                    HapticManager.shared.trigger(.success)
                }
            } catch {
                await MainActor.run {
                    self.isExtracting = false
                    ToastManager.shared.show(type: .error, message: error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    // MARK: - Clipboard Import
    private func performClipboardImport() {
        guard let clipboardContent = WikiPasteboard.string, !clipboardContent.isEmpty else {
            errorMessage = L10n.Ingest.tr("clipboardEmpty")
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
            title = L10n.Settings.tr("importedPageTitle")
        }

        // 填充到表单并显示
        newTitle = title
        newContent = content
        newType = .concept
        newTags = [L10n.Settings.tr("importTag")]
        manualFormTitle = L10n.Ingest.tr("clipboardImport") // 使用 "剪贴板" 或新增 "从剪贴板导入"
        
        withAnimation {
            showManualForm = true
        }
    }
}

// MARK: - Activity Row View
struct ActivityRow: View {
    @Environment(KMStore.self) var store
    @Environment(AppRouter.self) var router
    let item: ActivityItem
    let isCurrent: Bool
    @Binding var selectedTab: AppTab
    
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
                    router.navigate(to: .pageDetail(id: pageID))
                }) {
                    Text(L10n.Common.tr("view"))
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
