@preconcurrency import SwiftUI
import WebKit

@MainActor
struct NavigationView: View {
    @Environment(KMStore.self) var store
    @Binding var selectedTab: ContentView.AppTab
    var heroNamespace: Namespace.ID
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: SidebarSelection? = .tool(.dashboard)
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(heroNamespace: heroNamespace)
        } detail: {
            DetailContentView(selection: $selection, selectedTab: $selectedTab)
                .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
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
        switch selection {
        case .tool(.dashboard), .none:
            KnowledgeDashboardView()
        case .tool(.index):
            IndexView()
        case .tool(.lint):
            LintView()
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
            // chat视图已在主导航中处理
            KnowledgeDashboardView()
        case .tool(.weeklyReport):
            KnowledgeDashboardView()
        case .page(let id):
            if let page = store.pages.first(where: { $0.id == id }) {
                PageDetailView(page: page)
            } else {
                ContentUnavailableView("Page not found", systemImage: "doc.questionmark")
            }
        default:
            KnowledgeDashboardView()
        }
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
    @State private var pdfURL: IdentifiableURL?
    @State private var exportWebView: WKWebView?
    @State private var exportError: String?
    @State private var showExportError = false
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            synthesisButton(type: .mindmap)
                            synthesisButton(type: .slides)
                        }
                        GridRow {
                            synthesisButton(type: .quiz)
                            synthesisButton(type: .report)
                        }
                    }
                }
                .padding(.vertical, 16)
            } header: {
                Text(Localized.tr("aitask.tools"))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .textCase(nil)
                    .padding(.bottom, 8)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.wikiCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 0.5)
                    )
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            
            // 进行中的任务
            let runningTasks = taskCenter.tasks.filter { task in
                guard task.type == .synthesis else { return false }
                if case .running = task.status { return true }
                return false
            }
            
            if !runningTasks.isEmpty {
                Section {
                    ForEach(runningTasks) { task in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.wikiAccent.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                ProgressView()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.name)
                                    .font(.subheadline.weight(.semibold))
                                if case .running(let progress) = task.status {
                                    ProgressView(value: progress).tint(.wikiAccent)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text(Localized.tr("aitask.status.running")).font(.subheadline.bold()).foregroundStyle(.wikiAccent)
                }
            }
            
            // 文档列表
            Section {
                ForEach(KMStore.SynthesisType.allCases) { type in
                    DisclosureGroup {
                        if let doc = store.synthesisResults[type] {
                            Button(action: { outputType = type; showOutput = true }) {
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
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.wikiSecondary.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(Localized.tr("synthesis.noDocsThisType")).font(.caption).foregroundStyle(.wikiSecondary).padding(.vertical, 8)
                        }
                    } label: {
                        Label(type.title, systemImage: type.icon).font(.subheadline.bold())
                    }
                }
            } header: {
                Text(Localized.tr("synthesis.documentList")).font(.title3.bold()).padding(.top, 24)
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.synthesis"))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.trigger(.selection)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selection = .tool(.dashboard)
                    }
                    if !store.navigationPath.isEmpty {
                        store.navigationPath.removeLast(store.navigationPath.count)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.wikiText)
                        .frame(width: 32, height: 32)
                        .background(Color.wikiCard)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 2)
                }
            }
        }
        .sheet(isPresented: $showOutput) {
            outputSheet
        }
    }
    
    @ViewBuilder
    private var outputSheet: some View {
        NavigationStack {
            Group {
                if let doc = store.synthesisResults[outputType] {
                    if outputType == .mindmap {
                        MermaidWebView(mermaidCode: doc.content)
                    } else {
                        ScrollView {
                            MarkdownRendererView(content: doc.content, isPrivate: false, onLinkTap: { _ in })
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(outputType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localized.tr("misc.done")) { showOutput = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 18) {
                        Button {
                            if let doc = store.synthesisResults[outputType] {
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

    private func synthesisButton(type: KMStore.SynthesisType) -> some View {
        let state = store.synthesisStates[type] ?? .idle
        let hasResult = store.synthesisResults[type] != nil
        return Button(action: { store.performSynthesis(type: type) }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(hasResult ? Color.wikiAccent.opacity(0.05) : Color.wikiBackground.opacity(0.5)).frame(width: 56, height: 56)
                    Image(systemName: type.icon).font(.system(size: 28)).opacity(state == .generating ? 0.2 : 1.0)
                    if state == .generating { ProgressView().scaleEffect(1.2) }
                }
                Text(type.title).font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 24).fill(hasResult ? Color.wikiAccent.opacity(0.05) : Color.wikiBackground.opacity(0.4)))
            .foregroundStyle(hasResult || state == .generating ? .wikiAccent : .wikiSecondary)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(hasResult ? Color.wikiAccent.opacity(0.15) : Color.wikiBorder.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(store.pages.isEmpty)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func exportAction() {
        if outputType == .slides { exportToPPTX() } else { exportToPDF() }
    }
    
    private func exportToPPTX() {
        let content = store.synthesisResults[outputType]?.content ?? ""
        #if os(macOS)
        Task {
            do {
                let url = try await AISynthesisService.shared.convertToPPTX(markdown: content, title: outputType.title)
                await MainActor.run { self.pdfURL = IdentifiableURL(url: url); HapticManager.shared.trigger(.success) }
            } catch {
                await MainActor.run { self.exportError = error.localizedDescription; self.showExportError = true }
            }
        }
        #else
        exportToPDF()
        #endif
    }

    private func exportToPDF() {
        let content = store.synthesisResults[outputType]?.content ?? ""
        let webView = WKWebView()
        self.exportWebView = webView
        let html = "<html><body>\(content)</body></html>" // Simple fallback
        webView.loadHTMLString(html, baseURL: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.createPDF(configuration: WKPDFConfiguration()) { result in
                if case .success(let data) = result {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(outputType.title).pdf")
                    try? data.write(to: tempURL)
                    self.pdfURL = IdentifiableURL(url: tempURL)
                }
                self.exportWebView = nil
            }
        }
    }
}

// MARK: - 奖章系统 UI 组件
struct MedalCard: View {
    let medal: MedalService.Medal
    let isEarned: Bool
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(isEarned ? Color(hex: medal.colorHex).opacity(0.15) : Color.wikiBorder.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: medal.icon).font(.system(size: 32, weight: .bold)).foregroundStyle(isEarned ? Color(hex: medal.colorHex) : .wikiSecondary.opacity(0.5))
                if !isEarned { Image(systemName: "lock.fill").font(.caption2).padding(4).background(Circle().fill(.ultraThinMaterial)).offset(x: 25, y: 25) }
            }
            VStack(spacing: 4) {
                Text(Localized.tr(medal.titleKey)).font(.system(size: 14, weight: .bold)).foregroundStyle(isEarned ? .wikiText : .wikiSecondary)
                Text(Localized.tr(medal.descKey)).font(.system(size: 10)).foregroundStyle(.wikiSecondary).multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .padding(16).frame(maxWidth: .infinity).background(Color.wikiCard).clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isEarned ? Color(hex: medal.colorHex).opacity(0.3) : Color.wikiBorder.opacity(0.1), lineWidth: 1))
        .shadow(color: isEarned ? Color(hex: medal.colorHex).opacity(0.1) : .clear, radius: 10, y: 4)
    }
}

struct MedalRewardPopup: View {
    let medal: MedalService.Medal
    let onDismiss: () -> Void
    @State private var isAnimating = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color(hex: medal.colorHex).opacity(0.2)).frame(width: 200, height: 200).blur(radius: 40).scaleEffect(isAnimating ? 1.2 : 0.8)
                    Image(systemName: medal.icon).font(.system(size: 80, weight: .black)).foregroundStyle(LinearGradient(colors: [Color(hex: medal.colorHex), Color(hex: medal.colorHex).opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: Color(hex: medal.colorHex).opacity(0.5), radius: 20, y: 10).scaleEffect(isAnimating ? 1.1 : 0.9)
                }.padding(.top, 40)
                VStack(spacing: 12) {
                    Text(Localized.tr("medal.congrats")).font(.subheadline.bold()).foregroundStyle(.wikiAccent).kerning(2)
                    Text(Localized.tr(medal.titleKey)).font(.title.bold()).foregroundStyle(.wikiText)
                    Text(Localized.tr(medal.descKey)).font(.body).foregroundStyle(.wikiSecondary).multilineTextAlignment(.center).padding(.horizontal, 32)
                }
                Button(action: onDismiss) {
                    Text(Localized.tr("misc.awesome")).font(.headline).foregroundStyle(.white).frame(width: 200, height: 50).background(Capsule().fill(LinearGradient(colors: [Color(hex: medal.colorHex), Color(hex: medal.colorHex).opacity(0.8)], startPoint: .leading, endPoint: .trailing))).shadow(color: Color(hex: medal.colorHex).opacity(0.3), radius: 10, y: 5)
                }.padding(.bottom, 40)
            }
            .background(RoundedRectangle(cornerRadius: 32).fill(Color.wikiCard)).padding(24).scaleEffect(isAnimating ? 1 : 0.5).opacity(isAnimating ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) { isAnimating = true } }
    }
}

struct MedalWallView: View {
    @StateObject private var medalService = MedalService.shared
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    statBox(title: Localized.tr("medal.totalEarned"), value: "\(medalService.earnedMedalIDs.count)", icon: "trophy.fill", color: .orange)
                    statBox(title: Localized.tr("medal.progress"), value: "\(Int(Double(medalService.earnedMedalIDs.count) / 7.0 * 100))%", icon: "chart.bar.fill", color: .blue)
                }.padding(.horizontal)
                medalSection(title: Localized.tr("medal.category.explore"), category: .explore)
                medalSection(title: Localized.tr("medal.category.accumulation"), category: .accumulation)
                medalSection(title: Localized.tr("medal.category.connection"), category: .connection)
                Spacer(minLength: 40)
            }.padding(.vertical)
        }
        .background(Color.wikiBackground).navigationTitle(Localized.tr("medal.wall.title"))
    }
    private func medalSection(title: String, category: MedalService.Medal.Category) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title3.bold()).padding(.horizontal)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(medalService.allMedals.filter { $0.category == category }) { medal in
                    MedalCard(medal: medal, isEarned: medalService.earnedMedalIDs.contains(medal.id))
                }
            }.padding(.horizontal)
        }
    }
    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).foregroundStyle(color); Text(title).font(.caption).foregroundStyle(.wikiSecondary) }
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color.wikiCard).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
