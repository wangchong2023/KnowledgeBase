// LLMSettingsView.swift
//
// 作者: Wang Chong
// 功能说明: struct LLMSettingsView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

@preconcurrency import SwiftUI

// MARK: - LLM Settings View
@MainActor
struct LLMSettingsView: View {
    @EnvironmentObject var llmService: LLMService
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var showAPIKey = false
    @State private var isConfigExpanded = false
    
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
                    Text(Localized.tr("ondevice.assistMode"))
                        .font(.headline)
                        .foregroundStyle(.wikiText)
                    Text(Localized.tr("ondevice.assistDesc"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding(.vertical, 4)
                
                Toggle(Localized.tr("ondevice.enableAutoScan"), isOn: $llmService.autoScan)
                    .tint(.wikiAccent)
                
                Toggle(Localized.tr("ondevice.autoRefactor"), isOn: $llmService.autoRefactor)
                    .tint(.wikiAccent)
            } header: {
                Text(L10n.Settings.tr("advancedMaintenance"))
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
                        withAnimation {
                            isConfigExpanded = true
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
                DisclosureGroup(isExpanded: $isConfigExpanded) {
                    VStack(spacing: 20) {
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
                            .overlay(
                                RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                    .stroke(Color.wikiBorder.opacity(0.8), lineWidth: 1)
                            )
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                        .stroke(Color.wikiBorder.opacity(0.8), lineWidth: 1)
                                )
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                        .stroke(Color.wikiBorder.opacity(0.8), lineWidth: 1)
                                )
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
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label(Localized.tr("llm.configuration"), systemImage: "slider.horizontal.3")
                        .foregroundStyle(.wikiText)
                }
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
                                Text(Localized.tr("ondevice.connected"))
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
                                    Text(Localized.trf("ondevice.errorFormat", "\(code)"))
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
