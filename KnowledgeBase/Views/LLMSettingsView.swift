import SwiftUI

// MARK: - LLM Settings View
struct LLMSettingsView: View {
    @EnvironmentObject var llmService: LLMService
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var showAPIKey = false
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        Form {
            // Enable/Disable
            Section {
                Toggle(isOn: $llmService.isEnabled) {
                    Label(Localized.tr("llm.enableAssistant"), systemImage: "brain.head.profile.fill")
                        .foregroundStyle(.wikiText)
                }
                .tint(.wikiAccent)
            } header: {
                Text(Localized.tr("llm.status"))
            }
            
            // Provider
            Section {
                ForEach(LLMProvider.allCases) { provider in
                    Button(action: {
                        llmService.provider = provider
                        if !provider.defaultBaseURL.isEmpty {
                            llmService.baseURL = provider.defaultBaseURL
                        }
                        if !provider.defaultModel.isEmpty {
                            llmService.model = provider.defaultModel
                        }
                    }) {
                        HStack {
                            Image(systemName: provider.icon)
                                .foregroundStyle(.wikiAccent)
                            Text(provider.displayName)
                                .foregroundStyle(.wikiText)
                            Spacer()
                            if llmService.provider == provider {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.wikiAccent)
                            }
                        }
                    }
                }
            } header: {
                Text(Localized.tr("llm.provider"))
            }
            
            // Configuration
            Section {
                // API Key
                VStack(alignment: .leading, spacing: 6) {
                    Text(Localized.tr("llm.apiKey"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)
                    
                    HStack {
                        if showAPIKey {
                            TextField("sk-...", text: $llmService.apiKey)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.wikiText)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-...", text: $llmService.apiKey)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.wikiText)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Button(action: { showAPIKey.toggle() }) {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .padding()
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                }
                
                // Base URL
                VStack(alignment: .leading, spacing: 6) {
                    Text(Localized.tr("llm.apiAddress"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)
                    TextField("https://api.openai.com/v1", text: $llmService.baseURL)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.wikiText)
                        .padding()
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                // Model
                VStack(alignment: .leading, spacing: 6) {
                    Text(Localized.tr("llm.model"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.wikiSecondary)
                    TextField("gpt-4o-mini", text: $llmService.model)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.wikiText)
                        .padding()
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                        .autocapitalization(.none)
                }
                
                // Model suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedModels, id: \.self) { model in
                            Button(action: { llmService.model = model }) {
                                Text(model)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(llmService.model == model ? Color.wikiAccent.opacity(0.2) : Color.wikiCard)
                                    .clipShape(Capsule())
                                    .foregroundStyle(llmService.model == model ? .wikiAccent : .wikiSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text(Localized.tr("llm.configuration"))
            }
            
            // Test Connection
            Section {
                Button(action: testConnection) {
                    HStack {
                        if testing {
                            ProgressView()
                                .tint(.wikiAccent)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .foregroundStyle(.wikiAccent)
                        }
                        Text(testing ? Localized.tr("llm.testing") : Localized.tr("llm.testConnection"))
                            .foregroundStyle(.wikiText)
                    }
                }
                .disabled(testing || llmService.apiKey.isEmpty)
                
                if let result = testResult {
                    switch result {
                    case .success:
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(Localized.tr("llm.connectionSuccess"))
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    case .failure(let message):
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text(Localized.tr("llm.validation"))
            }
            
            // Chat History
            Section {
                HStack {
                    Label(Localized.tr("llm.chatHistory"), systemImage: "bubble.left.and.bubble.right")
                        .foregroundStyle(.wikiText)
                    Spacer()
                    Text("\(llmService.chatHistory.count) \(Localized.tr("llm.messages"))")
                        .foregroundStyle(.wikiSecondary)
                }
                
                Button(role: .destructive, action: {
                    llmService.clearChatHistory()
                }) {
                    Label(Localized.tr("llm.clearHistory"), systemImage: "trash")
                }
            } header: {
                Text(Localized.tr("llm.chatSection"))
            }
            
            // Info
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(icon: "lock.shield", text: Localized.tr("llm.info.localKey"))
                    InfoRow(icon: "doc.text", text: Localized.tr("llm.info.contextSent"))
                    InfoRow(icon: "network", text: Localized.tr("llm.info.openAICompatible"))
                    InfoRow(icon: "arrow.down.doc", text: Localized.tr("llm.info.smartIngest"))
                }
            } header: {
                Text(Localized.tr("llm.info"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("llm.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var suggestedModels: [String] {
        switch llmService.provider {
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .deepSeek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .custom:
            return ["default"]
        }
    }
    
    private func testConnection() {
        testing = true
        testResult = nil
        
        Task {
            do {
                let valid = try await llmService.validateAPIKey()
                await MainActor.run {
                    testing = false
                    testResult = valid ? .success : .failure(Localized.tr("llm.validationFailed"))
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }
}
