import SwiftUI

// MARK: - LLM Settings View
struct LLMSettingsView: View {
    @EnvironmentObject var llmService: LLMService
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var showAPIKey = false
    
    enum TestResult {
        case success(latency: Int)
        case failure(code: String, message: String, latency: Int?)
    }
    
    var body: some View {
        Form {
            // Enable/Disable
            Section {
                Toggle(isOn: $llmService.isEnabled) {
                    Label(Localized.tr("llm.enableAssistant"), systemImage: "sparkles")
                        .foregroundStyle(.wikiText)
                }
                .tint(.wikiAccent)
            } header: {
                Text(Localized.tr("llm.status"))
            }
            
            // Karpathy Mode
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI 维护助理 (Karpathy 模式)")
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Text("开启后，AI 会在维护中心为您提供页面重构建议（合并/拆分）并自动发现潜在的知识关联链接。")
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.vertical, 4)
                
                Toggle("启用自动扫描建议", isOn: .constant(true)) // 后续可绑定到持久化设置
                    .tint(.wikiAccent)
                
                Toggle("在编译时自动执行重构", isOn: .constant(false))
                    .tint(.wikiAccent)
            } header: {
                Text("高级维护设置")
            }
            
            // Provider
            Section {
                ForEach(LLMProvider.allCases) { provider in
                    Button(action: {
                        testResult = nil
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
                    TextField("https://api.example.com/v1", text: $llmService.baseURL)
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
                    TextField("model-name", text: $llmService.model)
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
                .disabled(testing || llmService.apiKey.isEmpty || llmService.baseURL.isEmpty)
                .opacity(llmService.apiKey.isEmpty || llmService.baseURL.isEmpty ? 0.6 : 1.0)
                
                if let result = testResult {
                    VStack(alignment: .leading, spacing: 8) {
                        switch result {
                        case .success(let latency):
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("连通正常")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("\(latency) ms")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.wikiSecondary)
                            }
                        case .failure(let code, let message, let latency):
                            HStack(alignment: .top) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("连通异常 (Error: \(code))")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.red)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.wikiSecondary)
                                }
                                Spacer()
                                if let l = latency {
                                    Text("\(l) ms")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.wikiSecondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
        llmService.provider.suggestedModels
    }
    
    private func testConnection() {
        testing = true
        testResult = nil
        
        Task {
            do {
                let res = try await llmService.validateAPIKey()
                await MainActor.run {
                    testing = false
                    if res.isSuccess {
                        testResult = .success(latency: res.latencyMS)
                    } else {
                        testResult = .failure(code: res.errorCode ?? "ERR", message: res.errorMessage ?? "Unknown Error", latency: res.latencyMS)
                    }
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testResult = .failure(code: "CATCH", message: error.localizedDescription, latency: nil)
                }
            }
        }
    }
}
