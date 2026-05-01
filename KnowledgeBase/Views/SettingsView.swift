import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @State private var showResetConfirmation = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @StateObject private var syncService = iCloudSyncService()
    @State private var selectedLanguage: LanguageMode = Localized.languageMode
    @Binding var languageForceUpdate: Bool
    
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
                        Label(Localized.tr("settings.appearanceMode"), systemImage: "paintbrush.fill")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.wikiAccent)
                    .id(languageForceUpdate)
                    
                    AccentColorPicker(colors: ["blue", "purple", "green", "orange", "pink", "red", "teal", "indigo"])
                        .id(languageForceUpdate)

                    Picker(selection: $selectedLanguage) {
                        ForEach(LanguageMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    } label: {
                        Label(Localized.tr("settings.language"), systemImage: "globe")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.wikiAccent)
                    .onChange(of: selectedLanguage) { _, newValue in
                        Localized.languageMode = newValue
                        languageForceUpdate.toggle()
                    }
                    .id(languageForceUpdate)
                } header: {
                    Text(Localized.tr("settings.section.appearance"))
                }
                
                // ── AI 配置 ──
                Section {
                    SettingsNavigationRow(icon: "brain.head.profile.fill", title: Localized.tr("tab.chat"), identifier: "AI-Chat") {
                        ChatView()
                    }

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
                    
                    ShareLink(item: exportAllAsMarkdown()) {
                        Label(Localized.tr("settings.exportMarkdown"), systemImage: "square.and.arrow.up")
                            .foregroundStyle(.wikiText)
                    }
                    
                    Button(action: importFromClipboard) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.body)
                                .foregroundStyle(.wikiSecondary)
                                .frame(width: 24)
                            Text(Localized.tr("settings.importClipboard"))
                                .font(.body)
                                .foregroundStyle(.wikiText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(Localized.tr("settings.section.data"))
                }
                
                // ── 更多功能 ──
                Section {
                    SettingsNavigationRow(icon: "waveform", title: Localized.tr("tab.voice"), identifier: "功能-语音笔记") {
                        VoiceNoteView()
                    }

                    SettingsNavigationRow(icon: "doc.richtext", title: Localized.tr("tab.pdf"), identifier: "功能-PDF") {
                        PDFLibraryView()
                    }

                    SettingsNavigationRow(icon: "person.2.fill", title: Localized.tr("tab.collab"), identifier: "功能-协作") {
                        CollaborationView()
                    }

                    SettingsNavigationRow(icon: "cube.transparent.fill", title: Localized.tr("settings.graph3D"), identifier: "功能-3D图谱") {
                        Graph3DView()
                    }

                    SettingsNavigationRow(icon: "visionpro", title: Localized.tr("settings.spatialComputing"), identifier: "功能-空间计算") {
                        VisionProSpatialView()
                    }
                } header: {
                    Text(Localized.tr("settings.section.moreFeatures"))
                }
                
                // ── 知识库统计 ──
                Section {
                    SettingsStatRow(icon: "doc.richtext.fill", label: Localized.tr("settings.totalPages"), value: "\(store.totalPages)")
                    SettingsStatRow(icon: "text.word.spacing", label: Localized.tr("settings.totalWords"), value: "\(store.totalWords)")
                    
                    SettingsStatRow(icon: "exclamationmark.triangle", label: Localized.tr("settings.stubPages"), value: "\(store.stubCount)")
                    
                    SettingsStatRow(icon: "clock", label: Localized.tr("settings.operationLog"), value: "\(store.logEntries.count)")
                } header: {
                    Text(Localized.tr("settings.section.stats"))
                }
                
                // ── 维护 ──
                Section {
                    SettingsNavigationRow(icon: "tag", title: Localized.tr("settings.tagManager"), identifier: "维护-标签管理") {
                        TagCloudView()
                    }

                    SettingsNavigationRow(icon: "stethoscope", title: Localized.tr("settings.healthCheck"), identifier: "维护-健康检查") {
                        LintView()
                    }

                    SettingsNavigationRow(icon: "list.bullet.indent", title: Localized.tr("settings.masterIndex"), identifier: "维护-总索引") {
                        IndexView()
                    }

                    SettingsNavigationRow(icon: "gauge.with.dots.needle.bottom.50percent", title: Localized.tr("perf.title")) {
                        PerformanceDashboardView(service: store.performanceService)
                    }
                } header: {
                    Text(Localized.tr("settings.section.maintenance"))
                }
                
                // ── 关于 ──
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "books.vertical.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.wikiAccent)
                            .frame(width: 32)
                        Text(Localized.tr("settings.aboutApp"))
                            .font(.body)
                            .foregroundStyle(.wikiText)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(Localized.tr("settings.section.about"))
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
            .alert(Localized.tr("settings.importComplete"), isPresented: $showImportSuccess) {
                Button(Localized.tr("settings.ok")) {}
            } message: {
                Text(Localized.trf("settings.importSuccess", Int(importedCount)))
            }
        }
    }
    
    private func importFromClipboard() {
        guard let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty else { return }
        
        var count = 0
        
        if let data = clipboardContent.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([WikiPage].self, from: data) {
            for page in decoded {
                if store.pageByTitle(page.title) == nil {
                    var newPage = page
                    newPage.id = UUID()
                    store.addImportedPage(newPage)
                    count += 1
                }
            }
        } else {
            let sections = clipboardContent.components(separatedBy: "\n---\n")
            for section in sections {
                let lines = section.components(separatedBy: "\n")
                guard let firstLine = lines.first else { continue }
                
                var title = firstLine
                    .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                if title.isEmpty { title = Localized.trf("settings.importedPageTitle", count + 1) }
                if store.pageByTitle(title) != nil { continue }
                
                let content = section.trimmingCharacters(in: .whitespacesAndNewlines)
                let page = store.createPage(
                    title: title,
                    type: .concept,
                    content: content,
                    tags: [Localized.tr("settings.importTag")]
                )
                _ = page
                count += 1
            }
        }
        
        if count > 0 {
            importedCount = count
            showImportSuccess = true
            store.saveToDisk()
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
