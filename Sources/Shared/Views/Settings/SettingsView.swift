import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

struct SettingsView: View {
    @Environment(KMStore.self) var store
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @State private var showResetConfirmation = false
    @StateObject private var syncService = iCloudSyncService()
    @State private var selectedLanguage: LanguageMode = Localized.languageMode
    @Binding var languageForceUpdate: Bool
    @State private var showFolderImporterForImport = false
    @State private var showClearAllConfirmation = false
    
    @MainActor
    private func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return await withCheckedContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: Localized.tr("security.unlockReason")) { success, _ in
                    continuation.resume(returning: success)
                }
            }
        } else {
            return true
        }
    }
    
    var body: some View {
        @Bindable var store = store
        
        let privacyBinding = Binding<Bool>(
            get: { store.isPrivacyModeEnabled },
            set: { newValue in
                Task {
                    if await authenticate() {
                        store.isPrivacyModeEnabled = newValue
                        HapticManager.shared.trigger(.success)
                    }
                }
            }
        )
        
        let biometricBinding = Binding<Bool>(
            get: { store.isBiometricEnabled },
            set: { newValue in
                Task {
                    if await authenticate() {
                        store.isBiometricEnabled = newValue
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
                        Label(Localized.tr("settings.systemTheme"), systemImage: "paintbrush.fill")
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
                        Label(Localized.tr("settings.systemLanguage"), systemImage: "globe")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.primary)
                    .onChange(of: selectedLanguage) { _, newValue in
                        Localized.languageMode = newValue
                        languageForceUpdate.toggle()
                    }
                    .id(languageForceUpdate)
                } header: {
                    Text(Localized.tr("settings.section.system"))
                }
                
                // ── AI 配置 ──
                Section {
                    SettingsNavigationRow(icon: "wrench.and.screwdriver.fill", title: Localized.tr("settings.llmConfig"), identifier: "settings.llm") {
                        LLMSettingsView()
                    } trailing: {
                        if llmService.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text(Localized.tr("settings.llmNotConfigured"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "cpu.fill", title: Localized.tr("settings.onDeviceLLM"), identifier: "settings.onDeviceLLM") {
                        OnDeviceLLMSettingsView()
                    }
                    
                    SettingsNavigationRow(icon: "flask.fill", title: Localized.tr("settings.promptWorkshop"), identifier: "settings.promptWorkshop") {
                        PromptWorkshopView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.ai"))
                }
                
                // ── 同步与备份 ──
                Section {
                    SettingsNavigationRow(icon: "icloud", title: Localized.tr("settings.iCloudSync"), identifier: "settings.icloud") {
                        iCloudSyncView(syncService: syncService, store: store)
                    } trailing: {
                        if syncService.iCloudAvailable {
                            Circle()
                                .fill(syncService.syncStatus == .synced ? Color.wikiAccent : Color.wikiSecondary)
                                .frame(width: 8, height: 8)
                        } else {
                            Text(Localized.tr("settings.unavailable"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "externaldrive.fill", title: Localized.tr("backup.title"), identifier: "settings.backup") {
                        BackupView()
                    }
                    
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label(Localized.tr("settings.reset"), systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("settings.reset")
                } header: {
                    Text(Localized.tr("settings.section.data"))
                }
                
                // ── 安全与隐私 ──
                Section {
                    Toggle(isOn: privacyBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Localized.tr("settings.privacyMode"))
                                Text(Localized.tr("settings.privacyMode.desc"))
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
                            Text(Localized.tr("settings.biometricProtection"))
                        } icon: {
                            Image(systemName: "faceid")
                                .foregroundStyle(.blue)
                        }
                    }
                    .accessibilityIdentifier("settings.biometric")
                } header: {
                    Text(Localized.tr("settings.section.security"))
                }
                
                // ── 开发者选项 ──
                #if DEBUG
                Section {
                    Button(action: {
                        DemoDataGenerator.generate(in: store.sqliteStore)
                        HapticManager.shared.trigger(.success)
                    }) {
                        Label(Localized.tr("settings.injectDemoData"), systemImage: "testtube.2")
                    }
                    .accessibilityIdentifier("settings.injectDemo")
                    
                    Button(role: .destructive, action: { showClearAllConfirmation = true }) {
                        Label(Localized.tr("settings.clearAllDataOnly"), systemImage: "trash.slash.fill")
                    }
                    .accessibilityIdentifier("settings.clearAll")

                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        HapticManager.shared.trigger(.success)
                    }) {
                        Label("重置引导流程", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    #if os(macOS)
                    Button(action: {
                        runPythonSeedScript()
                    }) {
                        Label(Localized.tr("settings.runPythonSeed"), systemImage: "terminal.fill")
                    }
                    .accessibilityIdentifier("settings.runPython")
                    #endif
                    
                    ShareLink(item: exportAllAsMarkdown()) {
                        Label(Localized.tr("settings.exportMarkdown"), systemImage: "doc.text.fill")
                    }
                } header: {
                    Text(Localized.tr("settings.section.developer"))
                }
                #endif

                Section {
                    SettingsNavigationRow(icon: "books.vertical.circle.fill", title: Localized.tr("settings.aboutApp"), identifier: "settings.about") {
                        SettingsAboutView()
                    }
                }
            }
            #if DEBUG
            .confirmationDialog(Localized.tr("settings.clearAllDataOnly"), isPresented: $showClearAllConfirmation) {
                Button(Localized.tr("misc.delete"), role: .destructive) {
                    store.sqliteStore.removeAllPages()
                }
                Button(Localized.tr("settings.cancel"), role: .cancel) {}
            } message: {
                Text(Localized.tr("settings.confirmClearAll"))
            }
            #endif
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("settings.settings"))
            .confirmationDialog(Localized.tr("settings.confirmReset"), isPresented: $showResetConfirmation) {
                Button(Localized.tr("settings.resetAllData"), role: .destructive) {
                    store.resetAllData()
                    store.seedDefaultContent()
                }
                Button(Localized.tr("settings.cancel"), role: .cancel) {}
            } message: {
                Text(Localized.tr("settings.resetWarning"))
            }
            // 导入文件夹
            .fileImporter(
                isPresented: $showFolderImporterForImport,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let taskID = TaskCenter.shared.addTask(type: .ingest, name: Localized.tr("import.externalVault"), target: url.lastPathComponent)
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
                    print("Import failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
#if os(macOS)
    private func runPythonSeedScript() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        
        // 尝试定位脚本路径
        let scriptPath = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Tools/seed_data.py").path
        
        process.arguments = [scriptPath, "--path", store.sqliteStore.dbPath.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                store.sqliteStore.reloadFromDisk()
                HapticManager.shared.trigger(.success)
            } else {
                HapticManager.shared.trigger(.error)
            }
        } catch {
            print("Failed to run python script: \(error)")
            HapticManager.shared.trigger(.error)
        }
    }
#endif

    private func exportAllAsMarkdown() -> String {
        var output = "# \(Localized.tr("export.header"))\n\n"
        output += "\(Localized.tr("export.exportTime")): \(Date().formatted())\n"
        output += "\(Localized.tr("export.totalPages")): \(store.totalPages)\n\n---\n\n"
        
        for type in PageType.allCases {
            let typePages = store.pages.filter { $0.type == type }
            if typePages.isEmpty { continue }
            
            output += "## \(type.displayName) (\(typePages.count))\n\n"
            
            for page in typePages.sorted(by: { $0.title < $1.title }) {
                output += "---\n\n"
                output += "### \(page.title)\n\n"
                output += "- \(Localized.tr("export.type")): \(page.type.displayName)\n"
                output += "- \(Localized.tr("export.status")): \(page.status.displayName)\n"
                output += "- \(Localized.tr("export.confidence")): \(page.confidence.displayName)\n"
                if !page.tags.isEmpty {
                    output += "- \(Localized.tr("export.tags")): \(page.tags.joined(separator: ", "))\n"
                }
                if !page.aliases.isEmpty {
                    output += "- \(Localized.tr("export.aliases")): \(page.aliases.joined(separator: ", "))\n"
                }
                output += "- \(Localized.tr("export.created")): \(page.created.formatted())\n"
                output += "- \(Localized.tr("export.updated")): \(page.updated.formatted())\n\n"
                output += page.content
                output += "\n\n"
            }
        }
        
        return output
    }
}
