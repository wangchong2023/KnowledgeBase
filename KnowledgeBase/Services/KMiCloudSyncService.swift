import Foundation
import CloudKit

// MARK: - iCloud Sync Error
enum iCloudSyncError: LocalizedError {
    case iCloudNotAvailable
    case cloudKitError(Error)
    case encodingError
    case decodingError
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable: return L.tr("icloud.error.notAvailable")
        case .cloudKitError(let error): return "\(L.tr("icloud.error.cloudKit"))：\(error.localizedDescription)"
        case .encodingError: return L.tr("icloud.error.encoding")
        case .decodingError: return L.tr("icloud.error.decoding")
        case .conflictResolutionFailed: return L.tr("icloud.error.conflictResolution")
        }
    }
}

// MARK: - Sync Status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
    
    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
    
    var label: String {
        switch self {
        case .idle: return L.tr("sync.idle")
        case .syncing: return L.tr("sync.syncing")
        case .synced: return L.tr("sync.synced")
        case .error(let msg): return "\(L.tr("sync.error"))：\(msg)"
        }
    }
}

// MARK: - iCloud Sync Service
/// Handles bidirectional sync of Knowledge Base data via CloudKit.
/// Uses a single CKRecord type "KMData" with:
///   - "pagesData": JSON-encoded [WikiPage]
///   - "logEntriesData": JSON-encoded [LogEntry]
///   - "lastModified": Date
class iCloudSyncService: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var iCloudAvailable: Bool = false

    private let container: CKContainer?
    private let database: CKDatabase?
    private let zoneID = CKRecordZone.ID(zoneName: "KMZone")
    private let recordType = "KMData"
    
    /// Whether CloudKit is available on this device/simulator
    let cloudKitAvailable: Bool
    
    // Callbacks for data exchange
    var onRemoteDataReceived: (([WikiPage], [LogEntry]) -> Void)?
    var onConflictDetected: (([WikiPage], [LogEntry], [WikiPage], [LogEntry]) -> ConflictResolution)?
    
    init() {
        // Check if iCloud is available BEFORE touching CKContainer
        // CKContainer.default() can SIGTRAP on simulator or without proper entitlements
        #if targetEnvironment(simulator)
        cloudKitAvailable = false
        container = nil
        database = nil
        iCloudAvailable = false
        syncStatus = .error(L.tr("icloud.notAvailable"))
        #else
        let token = FileManager.default.ubiquityIdentityToken
        cloudKitAvailable = token != nil
        
        if cloudKitAvailable {
            let ckr = CKContainer.default()
            container = ckr
            database = ckr.privateCloudDatabase
        } else {
            container = nil
            database = nil
            iCloudAvailable = false
            syncStatus = .error(L.tr("icloud.notAvailable"))
        }
        #endif
    }
    
    // MARK: - iCloud Status Check
    func checkiCloudStatus() {
        guard let container else { return }
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.iCloudAvailable = (status == .available)
                if status != .available {
                    self?.syncStatus = .error(L.tr("icloud.notAvailable"))
                }
            }
        }
    }
    
    // MARK: - Push to iCloud
    func pushToCloud(pages: [WikiPage], logEntries: [LogEntry]) async throws {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        
        await MainActor.run { syncStatus = .syncing }
        
        do {
            // Ensure custom zone exists
            try await ensureZoneExists()
            
            // Encode data
            let pagesData = try JSONEncoder().encode(pages)
            let logsData = try JSONEncoder().encode(logEntries)
            
            // Create or update record
            let recordID = CKRecord.ID(recordName: "wikicraft_main", zoneID: zoneID)
            let record: CKRecord
            
            // Try to fetch existing record for merge
            do {
                let existing = try await database.record(for: recordID)
                record = existing
            } catch {
                record = CKRecord(recordType: recordType, recordID: recordID)
            }
            
            record["pagesData"] = pagesData as CKRecordValue
            record["logEntriesData"] = logsData as CKRecordValue
            record["lastModified"] = Date() as CKRecordValue
            
            _ = try await database.save(record)
            
            await MainActor.run {
                lastSyncDate = Date()
                syncStatus = .synced
            }
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
            throw iCloudSyncError.cloudKitError(error)
        }
    }
    
    // MARK: - Pull from iCloud
    func pullFromCloud() async throws -> ([WikiPage], [LogEntry]) {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        
        await MainActor.run { syncStatus = .syncing }
        
        do {
            try await ensureZoneExists()
            
            let recordID = CKRecord.ID(recordName: "wikicraft_main", zoneID: zoneID)
            let record = try await database.record(for: recordID)
            
            guard let pagesData = record["pagesData"] as? Data,
                  let logsData = record["logEntriesData"] as? Data else {
                throw iCloudSyncError.decodingError
            }
            
            let pages = try JSONDecoder().decode([WikiPage].self, from: pagesData)
            let logs = try JSONDecoder().decode([LogEntry].self, from: logsData)
            
            await MainActor.run {
                lastSyncDate = Date()
                syncStatus = .synced
            }
            
            return (pages, logs)
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist yet — that's fine
            await MainActor.run {
                syncStatus = .idle
            }
            return ([], [])
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
            throw iCloudSyncError.cloudKitError(error)
        }
    }
    
    // MARK: - Bidirectional Sync (Push + Pull with conflict resolution)
    func sync(localPages: [WikiPage], localLogs: [LogEntry]) async throws -> ([WikiPage], [LogEntry]) {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        
        await MainActor.run { syncStatus = .syncing }
        
        do {
            try await ensureZoneExists()
            
            let recordID = CKRecord.ID(recordName: "wikicraft_main", zoneID: zoneID)
            let _ = try JSONEncoder().encode(localPages)
            let _ = try JSONEncoder().encode(localLogs)
            
            // Try to fetch existing remote record
            var remotePages: [WikiPage] = []
            var remoteLogs: [LogEntry] = []
            var record: CKRecord
            
            do {
                let existing = try await database.record(for: recordID)
                record = existing
                
                if let pagesData = existing["pagesData"] as? Data,
                   let logsData = existing["logEntriesData"] as? Data {
                    remotePages = try JSONDecoder().decode([WikiPage].self, from: pagesData)
                    remoteLogs = try JSONDecoder().decode([LogEntry].self, from: logsData)
                }
            } catch {
                record = CKRecord(recordType: recordType, recordID: recordID)
            }
            
            // Conflict detection: if remote has newer data
            var finalPages = localPages
            var finalLogs = localLogs
            
            if !remotePages.isEmpty {
                let remoteDate = record["lastModified"] as? Date ?? Date.distantPast
                
                // Check if there's a conflict (both sides have been modified)
                let hasLocalChanges = lastSyncDate.map { remoteDate > $0 } ?? false
                let hasRemoteChanges = !remotePages.isEmpty
                
                if hasLocalChanges && hasRemoteChanges {
                    // Conflict — apply resolution strategy
                    let resolution = await resolveConflict(
                        localPages: localPages,
                        localLogs: localLogs,
                        remotePages: remotePages,
                        remoteLogs: remoteLogs
                    )
                    
                    switch resolution {
                    case .keepLocal:
                        break // finalPages/finalLogs already set to local
                    case .keepRemote:
                        finalPages = remotePages
                        finalLogs = remoteLogs
                    case .merge:
                        finalPages = mergePages(local: localPages, remote: remotePages)
                        finalLogs = mergeLogs(local: localLogs, remote: remoteLogs)
                    }
                } else if hasRemoteChanges && lastSyncDate != nil {
                    // Remote is newer, no local changes
                    finalPages = remotePages
                    finalLogs = remoteLogs
                }
            }
            
            // Push merged data
            let mergedPagesData = try JSONEncoder().encode(finalPages)
            let mergedLogsData = try JSONEncoder().encode(finalLogs)
            
            record["pagesData"] = mergedPagesData as CKRecordValue
            record["logEntriesData"] = mergedLogsData as CKRecordValue
            record["lastModified"] = Date() as CKRecordValue
            
            _ = try await database.save(record)
            
            await MainActor.run {
                lastSyncDate = Date()
                syncStatus = .synced
            }
            
            return (finalPages, finalLogs)
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
            throw iCloudSyncError.cloudKitError(error)
        }
    }
    
    // MARK: - Subscribe to Remote Changes
    func subscribeToRemoteChanges() async throws {
        guard let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        let subscription = CKDatabaseSubscription(subscriptionID: "wikicraft_all_changes")
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await database.save(subscription)
    }
    
    // MARK: - Fetch Remote Changes (called after push notification)
    func fetchRemoteChanges() async throws -> ([WikiPage], [LogEntry]) {
        return try await pullFromCloud()
    }
    
    // MARK: - Zone Management
    private func ensureZoneExists() async throws {
        guard let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        do {
            _ = try await database.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await database.save(zone)
        }
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflict(
        localPages: [WikiPage],
        localLogs: [LogEntry],
        remotePages: [WikiPage],
        remoteLogs: [LogEntry]
    ) async -> ConflictResolution {
        // If callback is set, ask the caller to resolve
        if let onConflict = onConflictDetected {
            return onConflict(localPages, localLogs, remotePages, remoteLogs)
        }
        // Default: merge (most data-preserving)
        return .merge
    }
    
    // MARK: - Merge Strategies
    private func mergePages(local: [WikiPage], remote: [WikiPage]) -> [WikiPage] {
        var merged = local
        
        for remotePage in remote {
            if let localIndex = merged.firstIndex(where: { $0.id == remotePage.id }) {
                // Same ID — keep the newer version
                let localPage = merged[localIndex]
                if remotePage.updated > localPage.updated {
                    merged[localIndex] = remotePage
                }
            } else if !merged.contains(where: { $0.title == remotePage.title }) {
                // New remote page — add it
                merged.append(remotePage)
            }
            // If title conflict with different ID — keep local
        }
        
        return merged
    }
    
    private func mergeLogs(local: [LogEntry], remote: [LogEntry]) -> [LogEntry] {
        var merged = local
        
        for remoteLog in remote {
            if !merged.contains(where: { $0.id == remoteLog.id }) {
                merged.append(remoteLog)
            }
        }
        
        // Sort by date
        merged.sort { $0.timestamp > $1.timestamp }
        
        // Keep only last 200 entries
        if merged.count > 200 {
            merged = Array(merged.prefix(200))
        }
        
        return merged
    }
}

// MARK: - Conflict Resolution
enum ConflictResolution: String, CaseIterable {
    case keepLocal      // Keep local data, overwrite remote
    case keepRemote     // Accept remote data, overwrite local
    case merge          // Merge both sides (default)

    var displayName: String {
        switch self {
        case .keepLocal: return L.tr("icloud.keepLocal")
        case .keepRemote: return L.tr("icloud.keepRemote")
        case .merge: return L.tr("icloud.merge")
        }
    }
}
