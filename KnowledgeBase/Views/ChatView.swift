import SwiftUI

// MARK: - Chat View
struct ChatView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var llmService: LLMService
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { llmService.clearChatHistory() }) {
                            Label(Localized.tr("chat.clearHistory"), systemImage: "trash")
                        }
                        
                        NavigationLink(destination: LLMSettingsView()) {
                            Label(Localized.tr("chat.llmSettings"), systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.wikiSecondary)
                    }
                    .accessibilityIdentifier("menu")
                }
            }
            .alert(Localized.tr("misc.error"), isPresented: $showError) {
                Button(Localized.tr("misc.ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
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
                LazyVStack(spacing: 16) {
                    if llmService.chatHistory.isEmpty {
                        chatWelcome
                    } else {
                        ForEach(llmService.chatHistory) { message in
                            ChatBubbleView(message: message, pages: store.pages)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            streamingBubble
                        }
                    }
                }
                .padding()
            }
            .onChange(of: llmService.chatHistory.count) {
                if let lastID = llmService.chatHistory.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
    }
    
    // MARK: - Chat Welcome
    private var chatWelcome: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            // 带光晕的图标
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 12)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiConcept],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .wikiAccent.opacity(0.3), radius: 12, x: 0, y: 6)
            }

            Text(Localized.tr("chat.welcomeTitle"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.wikiText)

            Text(Localized.tr("chat.welcomeDesc"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(suggestedQueries, id: \.self) { query in
                    Button(action: { sendMessage(query) }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.wikiAccent)
                            Text(query)
                                .font(.subheadline)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }
                        .padding()
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var suggestedQueries: [String] {
        let conceptCount = store.pages.filter { $0.type == .concept }.count
        
        if conceptCount > 0 {
            return [
                Localized.tr("chat.suggested.summarize"),
                Localized.tr("chat.suggested.connections"),
                Localized.tr("chat.suggested.gaps"),
                Localized.tr("chat.suggested.compare")
            ]
        } else {
            return [
                Localized.tr("chat.suggested.whatContent"),
                Localized.tr("chat.suggested.organize"),
                Localized.tr("chat.suggested.recommend"),
                Localized.tr("chat.suggested.explain")
            ]
        }
    }
    
    // MARK: - Streaming Bubble
    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "brain.head.profile.fill")
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(width: 28, height: 28)
                .background(Color.wikiAccent.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                if llmService.streamingContent.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.wikiSecondary)
                                .frame(width: 6, height: 6)
                                .modifier(PulsingDot(delay: Double.random(in: 0...0.5)))
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
            
            HStack(alignment: .bottom, spacing: 12) {
                TextField(Localized.tr("chat.inputPlaceholder"), text: $inputText, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .foregroundStyle(.wikiText)
                    .onSubmit { sendMessage() }
                
                Button(action: { sendMessage() }) {
                    Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? .wikiAccent : .wikiSecondary)
                }
                .accessibilityIdentifier("send")
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.wikiCard)
        }
    }
    
    private var canSend: Bool {
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading) || isLoading
    }
    
    // MARK: - Send Message
    private func sendMessage(_ overrideText: String? = nil) {
        let text = overrideText ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        if isLoading {
            llmService.cancelCurrentRequest()
            isLoading = false
            return
        }
        
        inputText = ""
        isLoading = true
        llmService.streamingContent = ""
        errorMessage = nil
        
        Task {
            do {
                let stream = llmService.chatStream(query: text, pages: store.pages)
                for try await chunk in stream {
                    await MainActor.run {
                        llmService.streamingContent += chunk
                    }
                }
                
                await MainActor.run {
                    llmService.streamingContent = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
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
                        llmService.saveChatHistoryPublic()
                    }
                    
                    llmService.streamingContent = ""
                    
                    if case LLMError.notConfigured = error {
                        // Will show banner
                    } else {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
}
