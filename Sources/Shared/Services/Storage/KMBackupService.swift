// KMBackupService.swift
//
// 作者: Wang Chong
// 功能说明: Automatic data backup and crash recovery service.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

// MARK: - Backup Service
/// Automatic data backup and crash recovery service.
/// Creates timestamped backups on each save, auto-cleans old backups, and recovers from crash.
final class BackupService: ObservableObject {
    @Published var backupEntries: [BackupEntry] = []
    @Published var lastBackupDate: Date?
    @Published var isAutoBackupEnabled: Bool = true
    
    /// Maximum number of backups to retain before auto-cleanup removes the oldest.
    private static let maxBackups = 20
    /// Minimum time interval (seconds) between consecutive auto-backups to avoid thrashing.
    private static let backupInterval: TimeInterval = 300
    
    let baseDirectory: URL
    
    struct BackupEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let pageCount: Int
        let totalWords: Int
        let fileName: String
        
        var displayName: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
        
        func fileSize(in directory: URL) -> String {
            let url = directory.appendingPathComponent(fileName)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return "—"
        }
    }
    
    // MARK: - Directory Helper
    static func defaultBackupDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("KM_Backups", isDirectory: true)
    }
    
    var backupDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("KM_Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Init
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadBackupEntries()
        checkForCrashRecovery()
    }
    
    // MARK: - Create Backup
    func createBackup(pages: [WikiPage]) {
        guard isAutoBackupEnabled else { return }
        
        // Throttle: don't backup too frequently
        if let last = lastBackupDate, Date().timeIntervalSince(last) < Self.backupInterval {
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "backup_\(formatter.string(from: timestamp)).json"
        
        do {
            let data = try encoder.encode(pages)
            let url = backupDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomicWrite)
            
            let entry = BackupEntry(
                id: UUID(),
                timestamp: timestamp,
                pageCount: pages.count,
                totalWords: pages.reduce(0) { $0 + $1.wordCount },
                fileName: fileName
            )
            backupEntries.append(entry)
            lastBackupDate = timestamp
            
            // Save entries index
            saveBackupEntries()
            
            // Clean old backups
            cleanOldBackups()
        } catch {
            LogService.shared.addLog(action: .error, target: "BackupService", details: String(format: Localized.tr("backup.log.createFailed"), error.localizedDescription))
        }
    }

    // MARK: - Restore Backup
    func restoreBackup(_ entry: BackupEntry) -> [WikiPage]? {
        let url = backupDirectory.appendingPathComponent(entry.fileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([WikiPage].self, from: data)
        } catch {
            LogService.shared.addLog(action: .error, target: "BackupService", details: String(format: Localized.tr("backup.log.restoreFailed"), error.localizedDescription))
            return nil
        }
    }

    // MARK: - Delete Backup
    func deleteBackup(_ entry: BackupEntry) {
        let url = backupDirectory.appendingPathComponent(entry.fileName)
        try? FileManager.default.removeItem(at: url)
        backupEntries.removeAll { $0.id == entry.id }
        saveBackupEntries()
    }

    // MARK: - Crash Recovery
    private func checkForCrashRecovery() {
        // Check if there's a "dirty flag" file indicating unsaved changes at crash
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")

        if FileManager.default.fileExists(atPath: dirtyFlag.path) {
            LogService.shared.addLog(action: .systemInit, target: "BackupService", details: Localized.tr("backup.log.crashRecovery"))
            // The dirty flag means the app crashed before completing a save
            // BackupService will make the latest backup available for recovery
            try? FileManager.default.removeItem(at: dirtyFlag)
        }
    }

    func markDirty() {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        try? Data().write(to: dirtyFlag)
    }

    func markClean() {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        try? FileManager.default.removeItem(at: dirtyFlag)
    }

    var hasUnsavedChanges: Bool {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        return FileManager.default.fileExists(atPath: dirtyFlag.path)
    }

    // MARK: - Clean Old Backups
    private func cleanOldBackups() {
        guard backupEntries.count > Self.maxBackups else { return }

        let sorted = backupEntries.sorted { $0.timestamp > $1.timestamp }
        let toRemove = sorted.suffix(from: Self.maxBackups)

        for entry in toRemove {
            let url = backupDirectory.appendingPathComponent(entry.fileName)
            try? FileManager.default.removeItem(at: url)
        }

        backupEntries = Array(sorted.prefix(Self.maxBackups))
        saveBackupEntries()
    }

    // MARK: - Persistence
    private func saveBackupEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(backupEntries)
            let url = backupDirectory.appendingPathComponent("backup_index.json")
            try data.write(to: url, options: .atomicWrite)
        } catch {
            LogService.shared.addLog(action: .error, target: "BackupService", details: String(format: Localized.tr("backup.log.saveIndexFailed"), error.localizedDescription))
        }
    }
    
    private func loadBackupEntries() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let url = backupDirectory.appendingPathComponent("backup_index.json")
        do {
            let data = try Data(contentsOf: url)
            backupEntries = try decoder.decode([BackupEntry].self, from: data)
            lastBackupDate = backupEntries.last?.timestamp
        } catch {
            // No index file yet, scan directory
            scanBackupDirectory()
        }
    }
    
    private func scanBackupDirectory() {
        let dir = backupDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [URLResourceKey.creationDateKey]) else { return }
        
        var entries: [BackupEntry] = []
        for file in files where file.lastPathComponent.hasPrefix("backup_") && file.pathExtension == "json" {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: file),
               let pages = try? decoder.decode([WikiPage].self, from: data) {
                let entry = BackupEntry(
                    id: UUID(),
                    timestamp: (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
                    pageCount: pages.count,
                    totalWords: pages.reduce(0) { $0 + $1.wordCount },
                    fileName: file.lastPathComponent
                )
                entries.append(entry)
            }
        }
        backupEntries = entries.sorted { $0.timestamp > $1.timestamp }
        lastBackupDate = backupEntries.first?.timestamp
    }
}
