import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: KMStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var llmService: LLMService
    @State private var showResetConfirmation = false
    @State private var showImportSuccess = false
    @State private var importedCount = 0
    @StateObject private var syncService = iCloudSyncService()
    
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
                        Label("外观模式", systemImage: "paintbrush.fill")
                            .foregroundStyle(.wikiText)
                    }
                    .tint(.wikiAccent)
                    
                    AccentColorPicker(colors: ["blue", "purple", "green", "orange", "pink", "red", "teal", "indigo"])
                } header: {
                    Text("外观")
                }
                
                // ── AI 配置 ──
                Section {
                    SettingsNavigationRow(icon: "brain.head.profile.fill", title: L.tr("tab.chat"), identifier: "AI-Chat") {
                        ChatView()
                    }

                    SettingsNavigationRow(icon: "wrench.and.screwdriver.fill", title: "LLM 配置", identifier: "AI-LLM设置") {
                        LLMSettingsView()
                    } trailing: {
                        if llmService.isEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("未配置")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "cpu.fill", title: "端侧 LLM", identifier: "AI-端侧LLM") {
                        OnDeviceLLMSettingsView()
                    }
                } header: {
                    Text("AI")
                }
                
                // ── 数据管理 ──
                Section {
                    SettingsNavigationRow(icon: "icloud", title: "iCloud 同步", identifier: "数据-iCloud同步") {
                        iCloudSyncView(syncService: syncService, store: store)
                    } trailing: {
                        if syncService.iCloudAvailable {
                            Circle()
                                .fill(syncService.syncStatus == .synced ? Color.wikiAccent : Color.wikiSecondary)
                                .frame(width: 8, height: 8)
                        } else {
                            Text("不可用")
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }

                    SettingsNavigationRow(icon: "externaldrive.fill", title: L.tr("backup.title"), identifier: "数据-备份") {
                        BackupView()
                    }
                    
                    ShareLink(item: exportAllAsMarkdown()) {
                        Label("导出为 Markdown", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.wikiText)
                    }
                    
                    Button(action: importFromClipboard) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.body)
                                .foregroundStyle(.wikiSecondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("从剪贴板导入")
                                    .font(.body)
                                    .foregroundStyle(.wikiText)
                                Text("支持 JSON 数组或 Markdown 分隔文本")
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("数据管理")
                }
                
                // ── 更多功能 ──
                Section {
                    SettingsNavigationRow(icon: "waveform", title: L.tr("tab.voice"), subtitle: "语音录制并自动转写为知识条目", identifier: "功能-语音笔记") {
                        VoiceNoteView()
                    }

                    SettingsNavigationRow(icon: "doc.richtext", title: L.tr("tab.pdf"), subtitle: "导入、阅读与管理 PDF 文档") {
                        PDFLibraryView()
                    }

                    SettingsNavigationRow(icon: "person.2.fill", title: L.tr("tab.collab"), subtitle: "多人协作编辑与知识共享") {
                        CollaborationView()
                    }

                    SettingsNavigationRow(icon: "cube.transparent.fill", title: "3D 图谱", subtitle: "球形分布知识节点，旋转缩放查看全局") {
                        Graph3DView()
                    }

                    SettingsNavigationRow(icon: "visionpro", title: "空间计算", subtitle: "在 Apple Vision Pro 中沉浸式浏览") {
                        VisionProSpatialView()
                    }
                } header: {
                    Text("更多功能")
                }
                
                // ── 知识库统计 ──
                Section {
                    SettingsStatRow(icon: "doc.richtext.fill", label: "总页面", value: "\(store.totalPages)")
                    SettingsStatRow(icon: "text.word.spacing", label: "总字数", value: "\(store.totalWords)")
                    
                    SettingsStatRow(icon: "exclamationmark.triangle", label: "占位页面", value: "\(store.stubCount)")
                    Text("被链接但内容为空的页面，建议补充内容")
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary.opacity(0.7))
                    
                    SettingsStatRow(icon: "clock", label: "操作日志", value: "\(store.logEntries.count)")
                } header: {
                    Text("知识库统计")
                }
                
                // ── 维护 ──
                Section {
                    SettingsNavigationRow(icon: "tag", title: "标签管理", subtitle: "浏览所有标签及关联页面", identifier: "维护-标签管理") {
                        TagCloudView()
                    }

                    SettingsNavigationRow(icon: "stethoscope", title: "健康检查", identifier: "维护-健康检查") {
                        LintView()
                    }

                    SettingsNavigationRow(icon: "list.bullet.indent", title: "总索引", identifier: "维护-总索引") {
                        IndexView()
                    }

                    SettingsNavigationRow(icon: "gauge.with.dots.needle.bottom.50percent", title: L.tr("perf.title")) {
                        PerformanceDashboardView(service: store.performanceService)
                    }
                } header: {
                    Text("维护")
                }
                
                // ── 关于 ──
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "books.vertical.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.wikiAccent)
                            Text("知识库")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.wikiText)
                        }
                        
                        Text("基于 Karpathy LLM Wiki 方法论的 iOS 知识管理应用")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("关于")
                }
                
                // ── 危险操作 ──
                Section {
                    Button(role: .destructive, action: { showResetConfirmation = true }) {
                        Label("重置知识库", systemImage: "trash")
                    }
                    .accessibilityIdentifier("危险-重置知识库")
                } header: {
                    Text("危险操作")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle("设置")
            .confirmationDialog("确认重置", isPresented: $showResetConfirmation) {
                Button("重置所有数据", role: .destructive) {
                    store.resetAllData()
                    store.seedDefaultContent()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作将删除所有页面和日志，恢复为默认内容。不可恢复。")
            }
            .alert("导入完成", isPresented: $showImportSuccess) {
                Button("好的") {}
            } message: {
                Text("成功导入 \(importedCount) 个页面")
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
