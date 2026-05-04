// SettingsView.swift
//
// 作者: Wang Chong
// 功能说明: struct SettingsView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(KMStore.self) var store
    @Environment(SettingsStore.self) var settingsStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @ObservedObject var onboardingService: OnboardingService
    @State private var showResetConfirmation = false
    @State private var showInjectConfirmation = false
    @State private var showPerformanceTestConfirmation = false
    @State private var injectedCount: Int = 0
    @State private var showResetOnboardingConfirmation = false
    @State private var isExportingAll = false
    @State private var coordinator = iCloudSyncCoordinator()
    @State private var selectedLanguage: LanguageMode = Localized.languageMode
    @Binding var languageForceUpdate: Bool
    @State private var showFolderImporterForImport = false
    @State private var showClearAllConfirmation = false
    
    @MainActor
    private func authenticate() async -> Bool {
        await store.securityService.authenticateWithBiometrics()
    }
    
    var body: some View {
        @Bindable var store = store
        
        let privacyBinding = Binding<Bool>(
            get: { settingsStore.isPrivacyModeEnabled },
            set: { newValue in
                Task {
                    if await authenticate() {
                        settingsStore.isPrivacyModeEnabled = newValue
                        HapticManager.shared.trigger(.success)
                    }
                }
            }
        )
        
        let biometricBinding = Binding<Bool>(
            get: { settingsStore.isBiometricEnabled },
            set: { newValue in
                Task {
                    if await authenticate() {
                        settingsStore.isBiometricEnabled = newValue
                        HapticManager.shared.trigger(.success)
                    }
                }
            }
        )

        return NavigationStack {
            List {
                // ── 外观 ──
                Section {
                    Picker(selection: $themeManager.colorSchemeMode) {
                        ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    } label: {
                        Label(L10n.Settings.tr("systemTheme"), systemImage: "paintbrush.fill")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.primary)
                    .id(languageForceUpdate)
                    
                    Picker(selection: $selectedLanguage) {
                        ForEach(LanguageMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    } label: {
                        Label(L10n.Settings.tr("systemLanguage"), systemImage: "globe")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.primary)
                    .onChange(of: selectedLanguage) { _, newValue in
                        Localized.languageMode = newValue
                        languageForceUpdate.toggle()
                    }
                    .id(languageForceUpdate)
                } header: {
                    Text(L10n.Settings.tr("section.system"))
                }
                
                // ── AI 配置 ──
                Section {
                    SettingsNavigationRow(icon: "wrench.and.screwdriver.fill", title: L10n.Settings.tr("llmConfig"), identifier: "settings.llm") {
                        LLMSettingsView()
                    } trailing: {
                        if llmService.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text(L10n.Settings.tr("llmNotConfigured"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "cpu.fill", title: L10n.Settings.tr("onDeviceLLM"), identifier: "settings.onDeviceLLM") {
                        OnDeviceLLMSettingsView()
                    }
                    
                    SettingsNavigationRow(icon: "flask.fill", title: L10n.Settings.tr("promptWorkshop"), identifier: "settings.promptWorkshop") {
                        PromptWorkshopView()
                    }
                } header: {
                    Text(L10n.Settings.Section.ai)
                }
                
                // ── 同步与备份 ──
                Section {
                    SettingsNavigationRow(icon: "icloud", title: L10n.Settings.tr("iCloudSync"), identifier: "settings.icloud") {
                        iCloudSyncView(coordinator: coordinator)
                    } trailing: {
                        if coordinator.iCloudAvailable {
                            Circle()
                                .fill(coordinator.syncStatus == .synced ? Color.wikiAccent : Color.wikiSecondary)
                                .frame(width: 8, height: 8)
                        } else {
                            Text(L10n.Settings.tr("unavailable"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "externaldrive.fill", title: L10n.Backup.title, identifier: "settings.backup") {
                        BackupView()
                    }
                    
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label(L10n.Settings.tr("reset"), systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("settings.reset")
                    .confirmationDialog(
                        L10n.Settings.tr("confirmReset"),
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.Settings.tr("resetAllData"), role: .destructive) {
                            store.resetAllData()
                            store.seedDefaultContent()
                            HapticManager.shared.trigger(.success)
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    } message: {
                        Text(L10n.Settings.tr("resetWarning"))
                    }
                } header: {
                    Text(L10n.Settings.Section.data)
                }
                
                // ── 安全与隐私 ──
                Section {
                    Toggle(isOn: privacyBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.Settings.tr("privacyMode"))
                                Text(L10n.Settings.tr("privacyMode.desc"))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                            }
                        } icon: {
                            Image(systemName: "eye.slash.fill")
                                .foregroundStyle(.wikiAccent)
                        }
                    }
                    .accessibilityIdentifier("settings.privacy")
                    
                    Toggle(isOn: biometricBinding) {
                        Label {
                            Text(L10n.Settings.tr("biometricProtection"))
                        } icon: {
                            Image(systemName: "faceid")
                                .foregroundStyle(.blue)
                        }
                    }
                    .accessibilityIdentifier("settings.biometric")

                    SettingsNavigationRow(icon: "clock.arrow.circlepath", title: L10n.Settings.tr("operationLog"), identifier: "settings.log") {
                        LogView()
                    }
                } header: {
                    Text(L10n.Settings.Section.security)
                }
                
                // ── 开发者选项 ──
                #if DEBUG
                Section {
                    Button(action: {
                        showInjectConfirmation = true
                    }) {
                        Label(L10n.Settings.tr("injectDemoData"), systemImage: "testtube.2")
                    }
                    .accessibilityIdentifier("settings.injectDemo")
                    .alert(L10n.Settings.tr("injectConfirm.title"), isPresented: $showInjectConfirmation) {
                        Button(L10n.Common.tr("confirm")) {
                            let count = store.generateDemoData()
                            HapticManager.shared.trigger(.success)
                            ToastManager.shared.show(type: .success, message: L10n.Settings.trf("injectDemo.successMessage", count))
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    } message: {
                        Text(L10n.Settings.tr("injectConfirm.message"))
                    }

                    Button(action: {
                        showPerformanceTestConfirmation = true
                    }) {
                        Label(L10n.Settings.tr("performanceTest"), systemImage: "speedometer")
                    }
                    .accessibilityIdentifier("settings.performanceTest")
                    .alert(L10n.Settings.tr("performanceTestConfirm.title"), isPresented: $showPerformanceTestConfirmation) {
                        Button(L10n.Common.tr("confirm")) {
                            injectedCount = store.generateStressTestData()
                            HapticManager.shared.trigger(.success)
                            ToastManager.shared.show(type: .success, message: L10n.Settings.trf("injectDemo.successMessage", injectedCount))
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    } message: {
                        Text(L10n.Settings.tr("performanceTestConfirm.message"))
                    }
                    
                    Button(role: .destructive, action: { showClearAllConfirmation = true }) {
                        Label(L10n.Settings.tr("clearAll"), systemImage: "trash.slash.fill")
                    }
                    .accessibilityIdentifier("settings.clearAll")
                    .confirmationDialog(L10n.Settings.tr("clearAll.confirmTitle"), isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
                        Button(L10n.Settings.tr("clearAll.action"), role: .destructive) {
                            store.clearAllDeveloperData()
                            HapticManager.shared.trigger(.success)
                            ToastManager.shared.show(type: .success, message: L10n.Settings.tr("clearAll.success"))
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    } message: {
                        Text(L10n.Settings.tr("clearAll.message"))
                    }

                    Button(action: {
                        showResetOnboardingConfirmation = true
                    }) {
                        Label(L10n.Settings.tr("resetOnboarding"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .alert(L10n.Settings.tr("resetOnboarding.title"), isPresented: $showResetOnboardingConfirmation) {
                        Button(L10n.Common.tr("confirm"), role: .destructive) {
                            onboardingService.reset()
                            HapticManager.shared.trigger(.success)
                            ToastManager.shared.show(type: .success, message: L10n.Settings.tr("resetOnboarding.success"))
                        }
                        Button(L10n.Common.tr("cancel"), role: .cancel) { }
                    } message: {
                        Text(L10n.Settings.tr("resetOnboarding.message"))
                    }
                } header: {
                    Text(L10n.Settings.tr("section.developer"))
                }
                #endif

                Section {
                    SettingsNavigationRow(icon: "books.vertical.circle.fill", title: L10n.Settings.about, identifier: "settings.about") {
                        SettingsAboutView()
                    }
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(L10n.Settings.title)
            // 导入文件夹
            .fileImporter(
                isPresented: $showFolderImporterForImport,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let taskID = TaskCenter.shared.addTask(type: .ingest, name: L10n.Transfer.tr("import.externalVault"), target: url.lastPathComponent)
                        Task {
                            let _ = url.startAccessingSecurityScopedResource()
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            await MainActor.run {
                                store.mountVault(at: url)
                                TaskCenter.shared.updateTask(taskID, status: .completed)
                                HapticManager.shared.trigger(.success)
                            }
                        }
                    }
                case .failure(let error):
                    HapticManager.shared.trigger(.error)
                    ToastManager.shared.show(type: .error, message: error.localizedDescription)
                }
            }
        }
    }
    
    private func exportAllAsMarkdown() -> String {
        var output = "# \(L10n.Transfer.tr("export.header"))\n\n"
        output += "\(L10n.Transfer.tr("export.exportTime")): \(Date().formatted())\n"
        output += "\(L10n.Transfer.tr("export.totalPages")): \(store.totalPages)\n\n---\n\n"
        
        for type in PageType.allCases {
            let typePages = store.pages.filter { $0.type == type }
            if typePages.isEmpty { continue }
            
            output += "## \(type.displayName) (\(typePages.count))\n\n"
            
            for page in typePages.sorted(by: { $0.title < $1.title }) {
                output += "---\n\n"
                output += "### \(page.title)\n\n"
                output += "- \(L10n.Transfer.tr("export.type")): \(page.type.displayName)\n"
                output += "- \(L10n.Transfer.tr("export.status")): \(page.status.displayName)\n"
                output += "- \(L10n.Transfer.tr("export.confidence")): \(page.confidence.displayName)\n"
                if !page.tags.isEmpty {
                    output += "- \(L10n.Transfer.tr("export.tags")): \(page.tags.joined(separator: ", "))\n"
                }
                if !page.aliases.isEmpty {
                    output += "- \(L10n.Transfer.tr("export.aliases")): \(page.aliases.joined(separator: ", "))\n"
                }
                output += "- \(L10n.Transfer.tr("export.created")): \(page.created.formatted())\n"
                output += "- \(L10n.Transfer.tr("export.updated")): \(page.updated.formatted())\n\n"
                output += page.content
                output += "\n\n"
            }
        }
        
        return output
    }
}
