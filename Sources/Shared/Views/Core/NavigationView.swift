@preconcurrency import SwiftUI

@MainActor
struct NavigationView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    var heroNamespace: Namespace.ID
    @State private var showCreateSheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var tooltipManager = TooltipManager.shared

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace)
        } detail: {
            DetailContentView(selectedTab: $selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct DetailContentView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    
    var body: some View {
        @Bindable var localStore = store
        let currentStore = store
        return NavigationStack(path: $localStore.navigationPath) {
            switch localStore.selectedTool {
            case .dashboard, .none:
                KnowledgeDashboardView()
            case .chat:
                ChatView()
            case .taskCenter:
                TaskCenterView()
            case .index:
                SearchView()
            case .lint:
                LintView()
            case .weeklyReport:
                WeeklyReportView()
            case .tagCloud:
                TagCloudView()
            case .pluginMarket:
                Text("Plugin Market")
            case .synthesis:
                SynthesisView()
            default:
                Text("Content")
            }
        }
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


struct SynthesisView: View {
    @Environment(KMStore.self) var store
    @StateObject private var promptService = PromptService.shared
    @State private var selectedPages: Set<UUID> = []
    @State private var showOutput = false
    @State private var outputType: OutputType = .mindmap
    @State private var generatedContent = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    enum OutputType: String, CaseIterable, Identifiable {
        case mindmap, slides, quiz, report
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mindmap: return Localized.tr("prompt.expert.mindmap.title")
            case .slides: return Localized.tr("prompt.expert.slides.title")
            case .quiz: return Localized.tr("prompt.expert.quiz.title")
            case .report: return Localized.tr("prompt.expert.report.title")
            }
        }
        var icon: String {
            switch self {
            case .mindmap: return "rectangle.stack.badge.person.crop"
            case .slides: return "play.rectangle"
            case .quiz: return "questionmark.circle"
            case .report: return "doc.text.magnifyingglass"
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundStyle(.wikiAccent)
                        Text(Localized.tr("sidebar.synthesis"))
                            .font(.title2.bold())
                    }
                    Text(Localized.tr("synthesis.intro"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            
            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        synthesisButton(type: .mindmap)
                        synthesisButton(type: .slides)
                    }
                    GridRow {
                        synthesisButton(type: .quiz)
                        synthesisButton(type: .report)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(Localized.tr("synthesis.actions"))
            }
            .listRowBackground(Color.clear)
            
            Section {
                if store.pages.isEmpty {
                    ContentUnavailableView(Localized.tr("search.noResults"), systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(store.pages) { (page: WikiPage) in
                        HStack {
                            Image(systemName: page.displayIcon)
                                .foregroundStyle(page.type.themedColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text(page.title)
                                    .font(.subheadline.weight(.medium))
                                Text(page.updated.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: selectedPages.contains(page.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedPages.contains(page.id) ? .wikiAccent : .wikiSecondary.opacity(0.3))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.shared.trigger(.selection)
                            if selectedPages.contains(page.id) {
                                selectedPages.remove(page.id)
                            } else {
                                selectedPages.insert(page.id)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text(Localized.tr("synthesis.selectPages"))
                    Spacer()
                    Button(selectedPages.count == store.pages.count ? Localized.tr("misc.deselectAll") : Localized.tr("misc.selectAll")) {
                        if selectedPages.count == store.pages.count {
                            selectedPages.removeAll()
                        } else {
                            selectedPages = Set(store.pages.map { $0.id })
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.synthesis"))
        .overlay {
            if isGenerating {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(Localized.tr("aitask.processing"))
                            .font(.headline)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .sheet(isPresented: $showOutput) {
            NavigationStack {
                ScrollView {
                    MarkdownRendererView(
                        content: generatedContent,
                        isPrivate: false,
                        onLinkTap: { _ in }
                    )
                    .padding()
                }
                .navigationTitle(outputType.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Localized.tr("misc.done")) {
                            showOutput = false
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = generatedContent
                            #endif
                            HapticManager.shared.trigger(.success)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
            }
        }
    }
    
    private func synthesisButton(type: OutputType) -> some View {
        Button(action: { generate(type: type) }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedPages.isEmpty ? Color.wikiCard : Color.wikiAccent.opacity(0.1))
            )
            .foregroundStyle(selectedPages.isEmpty ? .wikiSecondary : .wikiAccent)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedPages.isEmpty ? Color.clear : Color.wikiAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedPages.isEmpty || isGenerating)
    }
    
    private func generate(type: OutputType) {
        outputType = type
        isGenerating = true
        
        let pagesToProcess = store.pages.filter { selectedPages.contains($0.id) }
        let combinedContent = pagesToProcess.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        
        let prompt: String
        switch type {
        case .mindmap: prompt = promptService.mindmapPrompt
        case .slides: prompt = promptService.slidesPrompt
        case .quiz: prompt = promptService.quizPrompt
        case .report: prompt = promptService.reportPrompt
        }
        
        Task {
            do {
                let response = try await store.llmService.generate(prompt: prompt, systemPrompt: "You are a knowledge synthesis expert. Use the following sources:\n\n\(combinedContent)")
                await MainActor.run {
                    self.generatedContent = response
                    self.isGenerating = false
                    self.showOutput = true
                    HapticManager.shared.trigger(.success)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                    HapticManager.shared.trigger(.error)
                }
            }
        }
    }
}
