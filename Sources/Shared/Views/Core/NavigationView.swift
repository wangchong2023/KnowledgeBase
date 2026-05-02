@preconcurrency import SwiftUI
import WebKit

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
                ChatView(selectedTab: $selectedTab)
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
                Text(Localized.tr("synthesis.intro"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.vertical, 4)
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
                    ToolbarItem(placement: .topBarLeading) {
                        Button(Localized.tr("misc.done")) {
                            showOutput = false
                        }
                        .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 18) {
                            Button {
                                #if os(iOS)
                                UIPasteboard.general.string = generatedContent
                                #endif
                                HapticManager.shared.trigger(.success)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            
                            Button {
                                exportAction()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                    }
                }
                .sheet(item: $pdfURL) { identifiable in
                    ActivityView(activityItems: [identifiable.url])
                }
                .alert("Export Error", isPresented: $showExportError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(exportError ?? "Unknown error occurred.")
                }
            }
        }
    }

    @State private var pdfURL: IdentifiableURL?
    @State private var exportWebView: WKWebView?
    @State private var exportError: String?
    @State private var showExportError = false
    
    private func exportAction() {
        if outputType == .slides {
            exportToPPTX()
        } else {
            exportToPDF()
        }
    }
    
    private func exportToPPTX() {
        #if os(macOS)
        Task {
            do {
                let url = try await AISynthesisService.shared.convertToPPTX(markdown: generatedContent, title: outputType.title)
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
        #else
        // iOS Fallback: Export as PDF since native zip is unavailable
        exportToPDF()
        #endif
    }

    private func exportToPDF() {
        // 使用强引用的 WKWebView 来渲染 Markdown 并导出 PDF，防止被提前释放
        let webView = WKWebView()
        self.exportWebView = webView
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, 'PingFang SC', sans-serif; padding: 40px; line-height: 1.6; color: #333; }
                h1 { color: #000; border-bottom: 2px solid #eee; padding-bottom: 10px; margin-bottom: 20px; }
                h2 { color: #444; margin-top: 30px; border-left: 4px solid #007AFF; padding-left: 12px; }
                p { margin-bottom: 12px; }
                li { margin-bottom: 8px; }
                code { background: #f4f4f4; padding: 2px 4px; border-radius: 4px; font-family: monospace; }
                pre { background: #f4f4f4; padding: 15px; border-radius: 8px; overflow-x: auto; margin: 15px 0; }
                blockquote { border-left: 4px solid #ddd; padding-left: 20px; color: #666; font-style: italic; margin: 15px 0; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
                th { background-color: #f8f8f8; }
            </style>
        </head>
        <body>
            \(formatMarkdownToHTML(generatedContent))
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // 等待加载完成后导出
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                if case .success(let data) = result {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(outputType.title).pdf")
                    try? data.write(to: tempURL)
                    self.pdfURL = IdentifiableURL(url: tempURL)
                }
                // 清理强引用
                self.exportWebView = nil
            }
        }
    }
    
    private func formatMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        // 简单替换常见的 Markdown 语法为 HTML
        html = html.replacingOccurrences(of: "\n# ", with: "<h1>")
        html = html.replacingOccurrences(of: "\n## ", with: "<h2>")
        html = html.replacingOccurrences(of: "\n- ", with: "<li>")
        html = html.replacingOccurrences(of: "\n* ", with: "<li>")
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // 处理标题结尾
        // 注意：这是一个非常基础的转换，生产环境建议集成真正的 Markdown 解析库
        return html
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
        
        Task {
            do {
                let service = AISynthesisService.shared
                let response: String
                switch type {
                case .mindmap: response = try await service.generateMindMap(content: combinedContent)
                case .slides: response = try await service.generatePresentation(content: combinedContent)
                case .quiz: response = try await service.generateQuiz(content: combinedContent)
                case .report: response = try await service.generateReport(content: combinedContent)
                }

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
