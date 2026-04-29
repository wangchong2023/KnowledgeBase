import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @State private var showResetConfirmation = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @StateObject private var syncService = iCloudSyncService()
    @State private var selectedLanguage: LanguageMode = L.languageMode
    
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
                        Label(L.tr("settings.appearanceMode"), systemImage: "paintbrush.fill")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.wikiAccent)
                    
                    AccentColorPicker(colors: ["blue", "purple", "green", "orange", "pink", "red", "teal", "indigo"])

                    Picker(selection: $selectedLanguage) {
                        ForEach(LanguageMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    } label: {
                        Label(L.tr("settings.language"), systemImage: "globe")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.wikiAccent)
                    .onChange(of: selectedLanguage) { _, newValue in
                        L.languageMode = newValue
                    }
                } header: {
                    Text(L.tr("settings.section.appearance"))
                }
                
                // ── AI 配置 ──
                Section {
                    SettingsNavigationRow(icon: "brain.head.profile.fill", title: L.tr("tab.chat"), identifier: "AI-Chat") {
                        ChatView()
                    }

                    SettingsNavigationRow(icon: "wrench.and.screwdriver.fill", title: L.tr("settings.llmConfig"), identifier: "AI-LLM设置") {
                        LLMSettingsView()
                    } trailing: {
                        if llmService.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text(L.tr("settings.llmNotConfigured"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "cpu.fill", title: L.tr("settings.onDeviceLLM"), identifier: "AI-端侧LLM") {
                        OnDeviceLLMSettingsView()
                    }
                } header: {
                    Text(L.tr("settings.section.ai"))
                }
                
                // ── 数据管理 ──
                Section {
                    SettingsNavigationRow(icon: "icloud", title: L.tr("settings.iCloudSync"), identifier: "数据-iCloud同步") {
                        iCloudSyncView(syncService: syncService, store: store)
                    } trailing: {
                        if syncService.iCloudAvailable {
                            Circle()
                                .fill(syncService.syncStatus == .synced ? Color.wikiAccent : Color.wikiSecondary)
                                .frame(width: 8, height: 8)
                        } else {
                            Text(L.tr("settings.unavailable"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "externaldrive.fill", title: L.tr("backup.title"), identifier: "数据-备份") {
                        BackupView()
                    }
                    
                    ShareLink(item: exportAllAsMarkdown()) {
                        Label(L.tr("settings.exportMarkdown"), systemImage: "square.and.arrow.up")
                            .foregroundStyle(.wikiText)
                    }
                    
                    Button(action: importFromClipboard) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.body)
                                .foregroundStyle(.wikiSecondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.tr("settings.importClipboard"))
                                    .font(.body)
                                    .foregroundStyle(.wikiText)
                                Text(L.tr("settings.importClipboardHint"))
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(L.tr("settings.section.data"))
                }
                
                // ── 更多功能 ──
                Section {
                    SettingsNavigationRow(icon: "waveform", title: L.tr("tab.voice"), subtitle: L.tr("settings.voiceNote"), identifier: "功能-语音笔记") {
                        VoiceNoteView()
                    }

                    SettingsNavigationRow(icon: "doc.richtext", title: L.tr("tab.pdf"), subtitle: L.tr("settings.pdfManager") ) {
                        PDFLibraryView()
                    }

                    SettingsNavigationRow(icon: "person.2.fill", title: L.tr("tab.collab"), subtitle: L.tr("settings.collaboration")) {
                        CollaborationView()
                    }

                    SettingsNavigationRow(icon: "cube.transparent.fill", title: L.tr("settings.graph3D"), subtitle: L.tr("settings.graph3DHint")) {
                        Graph3DView()
                    }

                    SettingsNavigationRow(icon: "visionpro", title: L.tr("settings.spatialComputing"), subtitle: L.tr("settings.spatialComputingHint")) {
                        VisionProSpatialView()
                    }
                } header: {
                    Text(L.tr("settings.section.moreFeatures"))
                }
                
                // ── 知识库统计 ──
                Section {
                    SettingsStatRow(icon: "doc.richtext.fill", label: L.tr("settings.totalPages"), value: "\(store.totalPages)")
                    SettingsStatRow(icon: "text.word.spacing", label: L.tr("settings.totalWords"), value: "\(store.totalWords)")
                    
                    SettingsStatRow(icon: "exclamationmark.triangle", label: L.tr("settings.stubPages"), value: "\(store.stubCount)")
                    Text(L.tr("settings.stubPagesHint"))
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary.opacity(0.7))
                    
                    SettingsStatRow(icon: "clock", label: L.tr("settings.operationLog"), value: "\(store.logEntries.count)")
                } header: {
                    Text(L.tr("settings.section.stats"))
                }
                
                // ── 维护 ──
                Section {
                    SettingsNavigationRow(icon: "tag", title: L.tr("settings.tagManager"), subtitle: L.tr("settings.tagManagerHint"), identifier: "维护-标签管理") {
                        TagCloudView()
                    }

                    SettingsNavigationRow(icon: "stethoscope", title: L.tr("settings.healthCheck"), identifier: "维护-健康检查") {
                        LintView()
                    }

                    SettingsNavigationRow(icon: "list.bullet.indent", title: L.tr("settings.masterIndex"), identifier: "维护-总索引") {
                        IndexView()
                    }

                    SettingsNavigationRow(icon: "gauge.with.dots.needle.bottom.50percent", title: L.tr("perf.title")) {
                        PerformanceDashboardView(service: store.performanceService)
                    }
                } header: {
                    Text(L.tr("settings.section.maintenance"))
                }
                
                // ── 关于 ──
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "books.vertical.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.wikiAccent)
                            Text(L.tr("settings.aboutApp"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.wikiText)
                        }
                        
                        Text(L.tr("settings.aboutAppDesc"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L.tr("settings.section.about"))
                }
                
                // ── 危险操作 ──
                Section {
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label(L.tr("settings.reset"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("危险-重置知识库")
                } header: {
                    Text(L.tr("settings.section.danger"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("settings.settings"))
            .confirmationDialog(L.tr("settings.confirmReset"), isPresented: $showResetConfirmation) {
                Button(L.tr("settings.resetAllData"), role: .destructive) {
                    store.resetAllData()
                    store.seedDefaultContent()
                }
                Button(L.tr("settings.cancel"), role: .cancel) {}
            } message: {
                Text(L.tr("settings.resetWarning"))
            }
            .alert(L.tr("settings.importComplete"), isPresented: $showImportSuccess) {
                Button(L.tr("settings.ok")) {}
            } message: {
                Text(L.trf("settings.importSuccess", Int(importedCount)))
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
                
                if title.isEmpty { title = "导入页面 \(count + 1)" }
                if store.pageByTitle(title) != nil { continue }
                
                let content = section.trimmingCharacters(in: .whitespacesAndNewlines)
                let page = store.createPage(
                    title: title,
                    type: .concept,
                    content: content,
                    tags: ["导入"]
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
        var output = "# 知识库导出\n\n"
        output += "导出时间: \(Date().formatted())\n"
        output += "总页面: \(store.totalPages)\n\n---\n\n"
        
        for type in PageType.allCases {
            let typePages = store.pages.filter { $0.type == type }
            if typePages.isEmpty { continue }
            
            output += "## \(type.displayName) (\(typePages.count))\n\n"
            
            for page in typePages.sorted(by: { $0.title < $1.title }) {
                output += "---\n\n"
                output += "### \(page.title)\n\n"
                output += "- 类型: \(page.type.displayName)\n"
                output += "- 状态: \(page.status.displayName)\n"
                output += "- 可信度: \(page.confidence.displayName)\n"
                if !page.tags.isEmpty {
                    output += "- 标签: \(page.tags.joined(separator: ", "))\n"
                }
                if !page.aliases.isEmpty {
                    output += "- 别名: \(page.aliases.joined(separator: ", "))\n"
                }
                output += "- 创建: \(page.created.formatted())\n"
                output += "- 更新: \(page.updated.formatted())\n\n"
                output += page.content
                output += "\n\n"
            }
        }
        
        return output
    }
}
