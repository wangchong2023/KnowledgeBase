import SwiftUI
import WebKit

// MARK: - Chat View (entry point with NavigationStack)
struct ChatView: View {
    @Binding var selectedTab: ContentView.AppTab
    var body: some View {
        ChatViewContent(selectedTab: $selectedTab)
    }
}

// MARK: - Chat View Content (for use inside parent NavigationStack)
struct ChatViewContent: View {
    @Environment(KMStore.self) var store
    @EnvironmentObject var llmService: LLMService
    @StateObject private var promptService = PromptService.shared
    @Binding var selectedTab: ContentView.AppTab
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isInputFocused: Bool
    @State private var aiGeneratedQuestions: [String] = []
    @State private var isGeneratingAIQuestions = false
    @State private var showPrompts = false
    @State private var exportWebView: WKWebView?
    @State private var exportURL: IdentifiableURL?
    @State private var isSelectionMode = false
    @State private var selectedMessageIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if !llmService.isEnabled || llmService.apiKey.isEmpty {
                notConfiguredBanner
            }

            chatMessageList

            chatInputBar
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("chat.title"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Section {
                        Button(action: { }) {
                            Label("\(llmService.chatHistory.count) \(Localized.tr("llm.messages"))", systemImage: "bubble.left.and.bubble.right")
                        }
                        .disabled(true)
                        
                        Button(role: .destructive, action: { 
                            llmService.clearChatHistory() 
                        }) {
                            Label(Localized.tr("llm.clearHistory"), systemImage: "trash")
                        }
                    }
                    
                    if !llmService.chatHistory.isEmpty {
                        Section(Localized.tr("chat.exportConversation")) {
                            Button(action: {
                                withAnimation {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode { selectedMessageIDs.removeAll() }
                                }
                            }) {
                                Label(isSelectionMode ? Localized.tr("misc.done") : Localized.tr("chat.selectToExport"), systemImage: isSelectionMode ? "checkmark.circle.fill" : "checklist")
                            }

                            Button(action: exportAsMarkdown) {
                                Label(isSelectionMode && !selectedMessageIDs.isEmpty ? Localized.tr("chat.exportSelectedMarkdown") : Localized.tr("chat.exportMarkdown"), systemImage: "doc.text")
                            }
                            Button(action: exportAsPDF) {
                                Label(isSelectionMode && !selectedMessageIDs.isEmpty ? Localized.tr("chat.exportSelectedPDF") : Localized.tr("chat.exportPDF"), systemImage: "doc.richtext")
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: LLMSettingsView()) {
                            Label(Localized.tr("chat.llmSettings"), systemImage: "gearshape")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.wikiSecondary)
                }
                .accessibilityIdentifier("menu")
            }
        }
        .sheet(item: $exportURL) { identifiable in
            ActivityView(activityItems: [identifiable.url])
        }
        .alert(Localized.tr("misc.error"), isPresented: $showError) {
            Button(Localized.tr("misc.ok")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            // 异步生成 AI 启发式问题
            if !store.pages.isEmpty && llmService.isEnabled && aiGeneratedQuestions.isEmpty {
                isGeneratingAIQuestions = true
                do {
                    var questions = try await AISynthesisService.shared.generateInsightfulQuestions(pages: store.pages)
                    
                    // Fallback if AI returns empty or fails
                    if questions.isEmpty {
                        questions = [
                            Localized.tr("chat.fallback.q1"),
                            Localized.tr("chat.fallback.q2"),
                            Localized.tr("chat.fallback.q3")
                        ]
                    }
                    
                    await MainActor.run {
                        self.aiGeneratedQuestions = questions
                        self.isGeneratingAIQuestions = false
                    }
                } catch {
                    await MainActor.run {
                        self.aiGeneratedQuestions = [
                            Localized.tr("chat.fallback.q1"),
                            Localized.tr("chat.fallback.q2"),
                            Localized.tr("chat.fallback.q3")
                        ]
                        self.isGeneratingAIQuestions = false
                    }
                }
            }
        }
    }
    
    // MARK: - Not Configured Banner
    private var notConfiguredBanner: some View {
        NavigationLink(destination: LLMSettingsView()) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(Localized.tr("chat.configureFirst"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Chat Message List
    private var chatMessageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if llmService.chatHistory.isEmpty {
                        chatWelcome()
                    } else {
                        ForEach(llmService.chatHistory) { message in
                            messageRow(for: message)
                        }
                        
                        if isLoading {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 16)
            }
            .onChange(of: llmService.chatHistory.count) {
                if let lastID = llmService.chatHistory.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
            .onChange(of: llmService.streamingContent) {
                withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
            }
            .onChange(of: isLoading) {
                if isLoading {
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageRow(for message: ChatMessage) -> some View {
        ChatBubbleView(
            message: message, 
            pages: store.pages, 
            selectedTab: $selectedTab,
            isSelectionMode: isSelectionMode,
            isSelected: selectedMessageIDs.contains(message.id)
        )
        .id(message.id)
        .overlay {
            if isSelectionMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedMessageIDs.contains(message.id) {
                            selectedMessageIDs.remove(message.id)
                        } else {
                            selectedMessageIDs.insert(message.id)
                        }
                        HapticManager.shared.trigger(.selection)
                    }
            }
        }
    }

    private func chatWelcome(isSheet: Bool = false) -> some View {
        VStack(spacing: isSheet ? 12 : 8) {
            if !isSheet {
                // Remove Spacer to tighten layout

                // 带光晕的图标
                ZStack {
                    Circle()
                        .fill(Color.wikiAccent.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .blur(radius: 12)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.wikiAccent, .wikiConcept],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .wikiAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Text(Localized.tr("chat.welcomeTitle"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.wikiText)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. 我的指令 (置顶)
                    suggestionGroup(title: Localized.tr("chat.group.user"), icon: "pin.fill", queries: promptService.userShortcuts.map { $0.text })
                    
                    // 2. AI 启发 (动态生成)
                    if isGeneratingAIQuestions {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(Localized.tr("chat.ai.thinking"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .padding(.leading)
                    } else if !aiGeneratedQuestions.isEmpty {
                        suggestionGroup(title: Localized.tr("chat.group.ai"), icon: "sparkles", queries: aiGeneratedQuestions, color: .wikiAccent)
                    }
                    
                    // 3. 基础引导
                    suggestionGroup(title: Localized.tr("chat.group.base"), icon: "lightbulb", queries: defaultQueries)
                }
                .padding(.horizontal)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func suggestionGroup(title: String, icon: String, queries: [String], color: Color = .wikiSecondary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题现在支持点击直接触发“总体探索”
            Button(action: {
                HapticManager.shared.trigger(.link)
                let query = Localized.trf("chat.deepExplorePrompt", title)
                sendMessage(query)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Text(title)
                        .font(.caption.weight(.bold))
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 10))
                        .opacity(0.5)
                }
                .foregroundStyle(color)
                .padding(.leading, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            ForEach(queries, id: \.self) { query in
                Button(action: { 
                    HapticManager.shared.trigger(.link)
                    showPrompts = false
                    // 立即填充并发送，解决“填充不提交”的问题
                    inputText = query
                    sendMessage(query) 
                }) {
                    HStack {
                        Text(query)
                            .font(.subheadline)
                            .foregroundStyle(.wikiText)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.wikiAccent.opacity(0.7))
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                            .stroke(Color.wikiBorder.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var defaultQueries: [String] {
        let conceptCount = store.pages.filter { $0.type == .concept }.count
        if conceptCount > 0 {
            return [Localized.tr("chat.suggested.summarize"), Localized.tr("chat.suggested.connections")]
        } else {
            return [Localized.tr("chat.suggested.whatContent"), Localized.tr("chat.suggested.organize")]
        }
    }
    
    // MARK: - Streaming Bubble
    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(width: 28, height: 28)
                .background(Color.wikiAccent.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                if llmService.streamingContent.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Localized.tr("chat.aiThinking"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.wikiAccent)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.wikiAccent)
                                    .frame(width: 6, height: 6)
                                    .modifier(PulsingDot(delay: Double.random(in: 0...0.5)))
                            }
                        }
                    }
                } else {
                    Text(llmService.streamingContent)
                        .font(.subheadline)
                        .foregroundStyle(.wikiText)
                }
            }
            .padding(12)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - Chat Input Bar
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .center, spacing: 12) {
                Button(action: { showPrompts.toggle() }) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .foregroundStyle(llmService.chatHistory.isEmpty || isLoading ? .wikiSecondary.opacity(0.5) : .wikiAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.wikiCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(llmService.chatHistory.isEmpty || isLoading)
                
                TextField(isLoading ? Localized.tr("chat.aiRunning") : Localized.tr("chat.inputPlaceholder"), text: $inputText)
                    .font(.subheadline)
                    .focused($isInputFocused)
                    .foregroundStyle(isLoading ? .wikiSecondary : .wikiText)
                    .textFieldStyle(.plain)
                    .disabled(isLoading)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit { 
                        if canSend { sendMessage() }
                    }
                
                Button(action: { 
                    if isLoading {
                        llmService.cancelCurrentRequest()
                        isLoading = false
                    } else {
                        HapticManager.shared.trigger(.selection)
                        sendMessage() 
                    }
                }) {
                    Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isLoading ? .red : (canSend ? .wikiAccent : .wikiSecondary))
                        .symbolEffect(.bounce, value: isLoading)
                        .frame(width: 44, height: 44)
                }
                .accessibilityIdentifier("send")
                .disabled(!canSend && !isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isLoading ? Color.wikiCard.opacity(0.5) : Color.wikiCard)
            .sheet(isPresented: $showPrompts) {
                NavigationStack {
                    chatWelcome(isSheet: true)
                        .navigationTitle(Localized.tr("chat.explorationAndPrompts"))
#if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
#endif
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                Button(Localized.tr("misc.close")) { showPrompts = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private var canSend: Bool {
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading) || isLoading
    }
    
    // MARK: - Send Message
    private func sendMessage(_ overrideText: String? = nil) {
        let text = (overrideText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        HapticManager.shared.trigger(.link)
        
        if isLoading {
            llmService.cancelCurrentRequest()
            isLoading = false
            return
        }
        
        // 立即清除输入框并进入加载状态，提供瞬间反馈
        if overrideText == nil { inputText = "" }
        isLoading = true
        llmService.streamingContent = ""
        errorMessage = nil
        
        // 立即在 UI 中显示用户的消息
        let userMessage = ChatMessage(role: .user, content: text)
        llmService.chatHistory.append(userMessage)
        
        Task {
            do {
                // 立即在流中显示“思考中...”的即时感
                let stream = llmService.chatStream(query: text, pages: store.pages)
                
                var hasReceivedFirstChunk = false
                for try await chunk in stream {
                    if !hasReceivedFirstChunk {
                        hasReceivedFirstChunk = true
                        // 触发轻微触感，告知用户 AI 已开始输出
                        HapticManager.shared.trigger(.link)
                    }
                    
                    await MainActor.run {
                        llmService.streamingContent += chunk
                    }
                }
                
                await MainActor.run {
                    // 完成后处理
                    llmService.streamingContent = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // 即使出错，也保存已生成的片段
                    let partialContent = llmService.streamingContent
                    if !partialContent.isEmpty {
                        let linkedTitles = ChatLinkParser.extractWikiLinks(from: partialContent)
                        let relatedIDs = store.pages.filter { linkedTitles.contains($0.title) }.map(\.id)
                        let partialMessage = ChatMessage(
                            role: .assistant,
                            content: partialContent,
                            relatedPageIDs: relatedIDs
                        )
                        llmService.chatHistory.append(partialMessage)
                    }
                    
                    llmService.streamingContent = ""
                    
                    if case LLMError.notConfigured = error {
                        // Banner will handle
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Export Functions
    private func exportAsMarkdown() {
        let history = isSelectionMode && !selectedMessageIDs.isEmpty ? 
            llmService.chatHistory.filter { selectedMessageIDs.contains($0.id) } : 
            llmService.chatHistory
            
        var mdString = "# \(Localized.tr("chat.conversationHistory"))\n\n"
        for message in history {
            let roleName = message.role == .user ? "You" : "AI"
            mdString += "### \(roleName)\n"
            mdString += "\(message.content)\n\n"
        }
        
        let filename = isSelectionMode && !selectedMessageIDs.isEmpty ? "ChatSelection.md" : "ChatExport.md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? mdString.write(to: tempURL, atomically: true, encoding: .utf8)
        self.exportURL = IdentifiableURL(url: tempURL)
    }
    
    private func exportAsPDF() {
        let webView = WKWebView()
        self.exportWebView = webView
        
        let history = isSelectionMode && !selectedMessageIDs.isEmpty ? 
            llmService.chatHistory.filter { selectedMessageIDs.contains($0.id) } : 
            llmService.chatHistory

        var htmlContent = ""
        for message in history {
            let roleName = message.role == .user ? "You" : "AI"
            let color = message.role == .user ? "#007AFF" : "#333"
            let bgColor = message.role == .user ? "#F0F8FF" : "#F9F9F9"
            htmlContent += """
            <div style="background-color: \(bgColor); padding: 10px; margin-bottom: 10px; border-radius: 8px;">
                <h4 style="margin-top: 0; color: \(color);">\(roleName)</h4>
                <p style="white-space: pre-wrap; margin-bottom: 0;">\(message.content)</p>
            </div>
            """
        }
        
        let title = isSelectionMode && !selectedMessageIDs.isEmpty ? Localized.tr("chat.selectedHistory") : Localized.tr("chat.conversationHistory")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, sans-serif; padding: 20px; color: #333; line-height: 1.5; }
                h1 { border-bottom: 1px solid #ccc; padding-bottom: 10px; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                if case .success(let data) = result {
                    let filename = isSelectionMode && !selectedMessageIDs.isEmpty ? "ChatSelection.pdf" : "ChatExport.pdf"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                    try? data.write(to: tempURL)
                    self.exportURL = IdentifiableURL(url: tempURL)
                }
                self.exportWebView = nil
            }
        }
    }
}

