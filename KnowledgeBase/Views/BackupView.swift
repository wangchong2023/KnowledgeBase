import SwiftUI

// MARK: - Backup & Recovery View
struct BackupView: View {
    @EnvironmentObject var store: KMStore
    @StateObject private var backupService = BackupService()
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreConfirmation = false
    @State private var selectedEntry: BackupService.BackupEntry?
    @State private var showCreateBackup = false
    
    var body: some View {
        NavigationStack {
            List {
                // Auto Backup Toggle
                Section {
                    Toggle(isOn: $backupService.isAutoBackupEnabled) {
                        Label(L.tr("backup.autoBackup"), systemImage: "clock.arrow.circlepath")
                    }
                    
                    if let lastDate = backupService.lastBackupDate {
                        HStack {
                            Text(L.tr("backup.lastBackup"))
                                .foregroundStyle(.wikiSecondary)
                            Spacer()
                            Text(lastDate, style: .relative)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                } header: {
                    Text(L.tr("backup.settings")
                    )
                }
                
                // Manual Actions
                Section {
                    Button {
                        backupService.createBackup(pages: store.pages)
                        AccessibilityService.playHaptic(.medium)
                    } label: {
                        Label(L.tr("backup.createNow"), systemImage: "plus.circle.fill")
                    }
                    
                    Button {
                        store.saveToDisk()
                        backupService.markClean()
                    } label: {
                        Label(L.tr("backup.exportCurrent"), systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text(L.tr("backup.actions")
                    )
                }
                
                // Backup History
                Section {
                    if backupService.backupEntries.isEmpty {
                        ContentUnavailableView(
                            L.tr("backup.noBackups"),
                            systemImage: "archivebox",
                            description: Text(L.tr("backup.noBackupsDesc")
                            )
                        )
                    } else {
                        ForEach(backupService.backupEntries) { entry in
                            BackupEntryRow(entry: entry) {
                                selectedEntry = entry
                                showRestoreConfirmation = true
                            } onDelete: {
                                backupService.deleteBackup(entry)
                            }
                        }
                    }
                } header: {
                    Text(L.tr("backup.history")
                    )
                }
            }
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("backup.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .alert(L.tr("backup.restoreTitle"), isPresented: $showRestoreConfirmation) {
                Button(L.tr("backup.restore"), role: .destructive) {
                    restoreFromBackup()
                }
                Button(L.tr("misc.cancel"), role: .cancel) {}
            } message: {
                Text(L.tr("backup.restoreMessage")
                )
            }
        }
    }
    
    private func restoreFromBackup() {
        guard let entry = selectedEntry,
              let pages = backupService.restoreBackup(entry) else { return }
        
        // Save current state first (as a safety backup)
        backupService.createBackup(pages: store.pages)
        
        // Replace with backup data
        store.sqliteStore.replaceAllPages(pages)
        store.objectWillChange.send()
        store.saveToDisk()
        
        AccessibilityService.playNotificationHaptic(.success)
    }
}

// MARK: - Backup Entry Row
struct BackupEntryRow: View {
    let entry: BackupService.BackupEntry
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
                    Label("\(entry.pageCount) " + L.tr("backup.pages"), systemImage: "doc.richtext.fill")
                    Label("\(entry.totalWords) " + L.tr("backup.words"), systemImage: "textformat")
                    Label(entry.fileSize, systemImage: "externaldrive")
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
                Label(L.tr("misc.delete"), systemImage: "trash")
            }
        }
    }
}
