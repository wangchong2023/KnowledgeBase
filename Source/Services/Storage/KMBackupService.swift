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
        
        var fileSize: String {
            let url = BackupService.backupDirectory.appendingPathComponent(fileName)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return "—"
        }
    }
    
    // MARK: - Directory
    static var backupDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("KM_Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Init
    init() {
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
            let url = Self.backupDirectory.appendingPathComponent(fileName)
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
            print(String(format: Localized.tr("backup.log.createFailed"), error.localizedDescription))
        }
    }
    
    // MARK: - Restore Backup
    func restoreBackup(_ entry: BackupEntry) -> [WikiPage]? {
        let url = Self.backupDirectory.appendingPathComponent(entry.fileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([WikiPage].self, from: data)
        } catch {
            print(String(format: Localized.tr("backup.log.restoreFailed"), error.localizedDescription))
            return nil
        }
    }
    
    // MARK: - Delete Backup
    func deleteBackup(_ entry: BackupEntry) {
        let url = Self.backupDirectory.appendingPathComponent(entry.fileName)
        try? FileManager.default.removeItem(at: url)
        backupEntries.removeAll { $0.id == entry.id }
        saveBackupEntries()
    }
    
    // MARK: - Crash Recovery
    private func checkForCrashRecovery() {
        // Check if there's a "dirty flag" file indicating unsaved changes at crash
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dirtyFlag = docs.appendingPathComponent(".knowledge-management_dirty")
        
        if FileManager.default.fileExists(atPath: dirtyFlag.path) {
            print(Localized.tr("backup.log.crashRecovery"))
            // The dirty flag means the app crashed before completing a save
            // BackupService will make the latest backup available for recovery
            try? FileManager.default.removeItem(at: dirtyFlag)
        }
    }
    
    func markDirty() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dirtyFlag = docs.appendingPathComponent(".knowledge-management_dirty")
        try? Data().write(to: dirtyFlag)
    }
    
    func markClean() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dirtyFlag = docs.appendingPathComponent(".knowledge-management_dirty")
        try? FileManager.default.removeItem(at: dirtyFlag)
    }
    
    // MARK: - Clean Old Backups
    private func cleanOldBackups() {
        guard backupEntries.count > Self.maxBackups else { return }
        
        let sorted = backupEntries.sorted { $0.timestamp > $1.timestamp }
        let toRemove = sorted.suffix(from: Self.maxBackups)
        
        for entry in toRemove {
            let url = Self.backupDirectory.appendingPathComponent(entry.fileName)
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
            let url = Self.backupDirectory.appendingPathComponent("backup_index.json")
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print(String(format: Localized.tr("backup.log.saveIndexFailed"), error.localizedDescription))
        }
    }
    
    private func loadBackupEntries() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let url = Self.backupDirectory.appendingPathComponent("backup_index.json")
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
        let dir = Self.backupDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        
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
