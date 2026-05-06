// BackupView.swift
//
// 作者: Wang Chong
// 功能说明: struct BackupView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Backup & Recovery View
struct BackupView: View {
    @Environment(KMStore.self) var store
    @StateObject private var backupService = BackupService()
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreConfirmation = false
    @State private var selectedEntry: BackupService.BackupEntry?
    @State private var showCreateBackup = false
    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: BackupService.BackupEntry?
    
    var body: some View {
        NavigationStack {
            List {
                // Auto Backup Toggle
                Section {
                    Toggle(isOn: $backupService.isAutoBackupEnabled) {
                        Label(L10n.Backup.tr("autoBackup"), systemImage: "clock.arrow.circlepath")
                    }
                    
                    if let lastDate = backupService.lastBackupDate {
                        HStack {
                            Text(L10n.Backup.tr("lastBackup"))
                                .foregroundStyle(.wikiSecondary)
                            Spacer()
                            Text(lastDate.formatted(date: .numeric, time: .standard))
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                } header: {
                    Text(L10n.Backup.tr("settings"))
                }
                
                // Manual Actions
                Section {
                    Button {
                        backupService.createBackup(pages: store.pages)
                        AccessibilityService.playHaptic(.medium)
                    } label: {
                        Label(L10n.Backup.tr("createNow"), systemImage: "plus.circle.fill")
                    }
                    
                    Button {
                        store.saveToDisk()
                        backupService.markClean()
                    } label: {
                        Label(L10n.Backup.tr("exportCurrent"), systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text(L10n.Backup.tr("actions"))
                }
                
                // Backup History
                Section {
                    if backupService.backupEntries.isEmpty {
                        ContentUnavailableView(
                            L10n.Backup.tr("noBackups"),
                            systemImage: "archivebox",
                            description: Text(L10n.Backup.tr("noBackupsDesc"))
                        )
                    } else {
                        ForEach(backupService.backupEntries) { entry in
                            BackupEntryRow(entry: entry, backupDirectory: backupService.backupDirectory) {
                                selectedEntry = entry
                                showRestoreConfirmation = true
                            } onDelete: {
                                HapticFeedback.shared.trigger(.warning)
                                backupToDelete = entry
                                showDeleteConfirmation = true
                            }
                        }
                    }
                } header: {
                    Text(L10n.Backup.tr("history"))
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(L10n.Backup.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .confirmationDialog(
                L10n.Backup.tr("restoreTitle"),
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Backup.tr("restore"), role: .destructive) {
                    restoreFromBackup()
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { selectedEntry = nil }
            } message: {
                Text(L10n.Backup.tr("restoreMessage"))
            }
            .confirmationDialog(
                L10n.Backup.tr("deleteConfirmTitle"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.tr("delete"), role: .destructive) {
                    if let entry = backupToDelete {
                        backupService.deleteBackup(entry)
                        HapticFeedback.shared.trigger(.success)
                    }
                    backupToDelete = nil
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) { backupToDelete = nil }
            } message: {
                Text(L10n.Backup.tr("deleteConfirmMessage"))
            }
        }
    }
    
    private func restoreFromBackup() {
        guard let entry = selectedEntry,
              let pages = backupService.restoreBackup(entry) else { return }
        
        // Save current state first (as a safety backup)
        backupService.createBackup(pages: store.pages)
        
        // Replace with backup data
        store.replaceAllPages(pages)
        store.saveToDisk()
        
        AccessibilityService.playNotificationHaptic(.success)
    }
}

// MARK: - Backup Entry Row
struct BackupEntryRow: View {
    let entry: BackupService.BackupEntry
    let backupDirectory: URL
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title3)
                .foregroundStyle(.wikiAccent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                
                HStack(spacing: 12) {
                    Label("\(entry.pageCount) " + L10n.Backup.tr("pages"), systemImage: "doc.richtext.fill")
                    Label("\(entry.totalWords) " + L10n.Backup.tr("words"), systemImage: "textformat")
                    Label(entry.fileSize(in: backupDirectory), systemImage: "externaldrive")
                }
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
            }
            
            Spacer()
            
            Button {
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.wikiAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.Common.tr("delete"), systemImage: "trash")
            }
        }
    }
}
