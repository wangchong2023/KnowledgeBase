import SwiftUI

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

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        IngestHeroSection()

                        IngestEntryCardsSection(
                            showManualForm: $showManualForm,
                            newType: $newType
                        )

                        // Manual form (animated reveal)
                        if showManualForm {
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
                                onConfirmSmartIngest: confirmSmartIngest
                            )
                            .id("manualForm")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        IngestTipsSection()
                    }
                    .padding(.bottom, 40)
                }
                .background(Color.wikiBackground)
                .navigationTitle("导入")
                .alert("错误", isPresented: $showError) {
                    Button("确定") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
                .sheet(isPresented: $showIconPicker) {
                    IconPickerView(selectedIcon: $newCustomIcon)
                }
            }
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let page = store.ingestRawContent(
                    title: newTitle,
                    content: newContent,
                    type: newType
                )

                var updatedPage = page
                updatedPage.tags = tags
                updatedPage.customIcon = newCustomIcon
                store.updatePage(updatedPage)

                isIngesting = false
                ingestSuccess = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    resetForm()
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

        store.addLog(action: "智能导入", target: newTitle, details: "LLM 编译完成，类型: \(type.displayName)")

        smartResult = nil
        ingestSuccess = true

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
}
