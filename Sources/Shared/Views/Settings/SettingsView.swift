import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @State private var showResetConfirmation = false
    @StateObject private var syncService = iCloudSyncService()
    @State private var selectedLanguage: LanguageMode = Localized.languageMode
    @Binding var languageForceUpdate: Bool
    @State private var showFolderImporterForImport = false
    
    var body: some View {
        NavigationStack {
            List {
                // ── 外观 ──
                Section {
                    Picker(selection: $themeManager.colorSchemeMode) {
                        ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
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
                            Label(mode.displayName, systemImage: mode.icon)
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
                    SettingsNavigationRow(icon: "wrench.and.screwdriver.fill", title: Localized.tr("settings.llmConfig"), identifier: "AI-LLM设置") {
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

                    SettingsNavigationRow(icon: "cpu.fill", title: Localized.tr("settings.onDeviceLLM"), identifier: "AI-端侧LLM") {
                        OnDeviceLLMSettingsView()
                    }
                    
                    SettingsNavigationRow(icon: "flask.fill", title: "提示词工厂", identifier: "AI-提示词工厂") {
                        PromptWorkshopView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.ai"))
                }
                
                // ── 同步与备份 ──
                Section {
                    SettingsNavigationRow(icon: "icloud", title: Localized.tr("settings.iCloudSync"), identifier: "数据-iCloud同步") {
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

                    SettingsNavigationRow(icon: "externaldrive.fill", title: Localized.tr("backup.title"), identifier: "数据-备份") {
                        BackupView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.data"))
                }
                
                // ── 安全与隐私 ──
                Section {
                    Toggle(isOn: $store.isPrivacyModeEnabled) {
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
                    .accessibilityIdentifier("安全-隐私模式开关")
                    
                    SettingsNavigationRow(icon: "lock.shield.fill", title: Localized.tr("settings.vaultSecurity"), identifier: "安全-金库锁") {
                        SecuritySettingsView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.security"))
                }
                
                // ── 更多功能 ──
                Section {
                    SettingsNavigationRow(icon: "cube.transparent.fill", title: Localized.tr("settings.graph3D"), identifier: "功能-3D图谱") {
                        Graph3DView()
                    }

                    SettingsNavigationRow(icon: "visionpro", title: Localized.tr("settings.spatialComputing"), identifier: "功能-空间计算") {
                        VisionProSpatialView()
                    }
                    
                    SettingsNavigationRow(icon: "puzzlepiece.extension.fill", title: Localized.tr("sidebar.pluginMarket"), identifier: "功能-插件中心") {
                        PluginCenterView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.moreFeatures"))
                }
                
                // ── 危险操作 ──
                Section {
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label(Localized.tr("settings.reset"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("危险-重置知识库")
                } header: {
                    Text(Localized.tr("settings.section.danger"))
                }

                // ── 关于 ──
                Section {
                    SettingsNavigationRow(icon: "books.vertical.circle.fill", title: Localized.tr("settings.aboutApp"), identifier: "关于-应用") {
                        SettingsAboutView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.about"))
                }
            }
            .listStyle(.insetGrouped)
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
                        let taskID = TaskCenter.shared.addTask(type: .ingest, name: "载入外部库", target: url.lastPathComponent)
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
