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
    @State private var showFolderExporter = false
    
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
                    
                    SettingsNavigationRow(icon: "flask.fill", title: "Prompt 工坊", identifier: "AI-Prompt工坊") {
                        PromptWorkshopView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.ai"))
                }
                
                // ── 数据管理 ──
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
                    
                    Button(action: { showFolderExporter = true }) {
                        Label("同步知识库到物理文件夹", systemImage: "folder.badge.gearshape")
                            .foregroundStyle(.wikiText)
                    }
                    .accessibilityIdentifier("数据-物理同步")
                    
                    ShareLink(item: exportAllAsMarkdown()) {
                        Label(Localized.tr("settings.exportMarkdown"), systemImage: "square.and.arrow.up")
                            .foregroundStyle(.wikiText)
                    }
                } header: {
                    Text(Localized.tr("settings.section.data"))
                }
                
                // ── 更多功能 ──
                Section {
                    SettingsNavigationRow(icon: "cube.transparent.fill", title: Localized.tr("settings.graph3D"), identifier: "功能-3D图谱") {
                        Graph3DView()
                    }

                    SettingsNavigationRow(icon: "visionpro", title: Localized.tr("settings.spatialComputing"), identifier: "功能-空间计算") {
                        VisionProSpatialView()
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

                // ── 关于（最底部）──
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
            .fileExporter(
                isPresented: $showFolderExporter,
                document: MarkdownFolderDocument(pages: store.pages),
                contentType: .folder,
                defaultFilename: "WorkBuddy_Wiki"
            ) { result in
                if case .success(let url) = result {
                    try? store.exportToFolder(at: url)
                    HapticManager.success()
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
