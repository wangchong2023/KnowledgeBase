// KMiCloudSyncService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了基于 CloudKit 的云端同步服务（iCloudSyncService），负责知识金库跨设备的数据一致性。
// 该服务采用专有区域（Custom Zone）进行数据存储，核心机制包括：
// 1. 差异化同步：通过对比本地与云端的 lastModified 时间戳，智能决定推送到云端或拉取到本地。
// 2. 冲突解决：提供“保留本地”、“保留云端”及“智能合并”三种策略，并在检测到数据冲突时通过回调通知 UI 层。
// 3. 数据压缩与安全：将 WikiPage 与 LogEntry 序列化为 JSON 格式存储于 CKRecord 中，确保存储效率。
// 4. 环境适配：针对模拟器与不同平台（iOS/macOS）进行了运行环境审计，确保在无 Entitlements 环境下优雅降级。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 完善全工程中文文档规范，增加详细的同步逻辑说明与函数注释
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

#if ICLOUD_ENABLED
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
        case .iCloudNotAvailable: return L10n.ICloud.tr("error.notAvailable")
        case .cloudKitError(let error): return "\(L10n.ICloud.tr("error.cloudKit"))：\(error.localizedDescription)"
        case .encodingError: return L10n.ICloud.tr("error.encoding")
        case .decodingError: return L10n.ICloud.tr("error.decoding")
        case .conflictResolutionFailed: return L10n.ICloud.tr("error.conflictResolution")
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
        case .idle: return Localized.tr("sync.idle")
        case .syncing: return Localized.tr("sync.syncing")
        case .synced: return Localized.tr("sync.synced")
        case .error(let msg): return "\(Localized.tr("sync.error"))：\(msg)"
        }
    }
}

// MARK: - iCloud Sync Service
/// Handles bidirectional sync of Knowledge Base data via CloudKit.
/// Uses a single CKRecord type "KMData" with:
///   - "pagesData": JSON-encoded [WikiPage]
///   - "logEntriesData": JSON-encoded [LogEntry]
///   - "lastModified": Date
@MainActor
class iCloudSyncService: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var iCloudAvailable: Bool = false

    private let container: CKContainer?
    private let database: CKDatabase?
    private let zoneID = CKRecordZone.ID(zoneName: "KMZone")
    private let recordType = "KMData"

    /// CloudKit 在当前设备/模拟器上是否可用（硬件与配置层）
    let cloudKitAvailable: Bool

    // MARK: - 回调钩子
    
    /// 当从云端拉取到新数据时的回调
    var onRemoteDataReceived: (([WikiPage], [LogEntry]) -> Void)?
    
    /// 当检测到同步冲突时的回调，需返回冲突解决策略
    var onConflictDetected: (([WikiPage], [LogEntry], [WikiPage], [LogEntry]) -> ConflictResolution)?

    /**
     * @description: 初始化同步服务，检测 iCloud 账户状态并配置 CloudKit 容器
     * @return {*}
     */
    init() {
        // Check if iCloud is available BEFORE touching CKContainer
        // CKContainer.default() can SIGTRAP on simulator or Mac Catalyst without proper entitlements
        //
        // Note: targetEnvironment(simulator) only matches iOS Simulator (iphonesimulator SDK).
        // Mac Catalyst uses iphoneos SDK, so we also check for Mac Catalyst via compiler flag.
        // We use canImport to detect macOS and wrap CloudKit access safely.
        #if targetEnvironment(simulator)
        cloudKitAvailable = false
        container = nil
        database = nil
        iCloudAvailable = false
        syncStatus = .error(L10n.ICloud.tr("notAvailable"))
        #elseif canImport(AppKit)
        // Mac Catalyst or macOS: CloudKit may not work without proper entitlements
        // Gracefully disable rather than crash
        cloudKitAvailable = false
        container = nil
        database = nil
        iCloudAvailable = false
        syncStatus = .error(L10n.ICloud.tr("notAvailable"))
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
            syncStatus = .error(L10n.ICloud.tr("notAvailable"))
        }
        #endif
    }

    // MARK: - 状态审计
    
    /**
     * @description: 异步检查当前 iCloud 账户的登录状态，并更新 iCloudAvailable 标记
     * @return {*}
     */
    func checkiCloudStatus() {
        guard let container else { return }
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                self?.iCloudAvailable = (status == .available)
                if status != .available {
                    self?.syncStatus = .error(L10n.ICloud.tr("notAvailable"))
                }
            }
        }
    }

    // MARK: - 云端推送
    
    /**
     * @description: 将本地数据强制推送到 iCloud，不进行冲突比对
     * @param { [WikiPage] } pages 待推送的页面列表
     * @param { [LogEntry] } logEntries 待推送的日志记录
     * @return {*}
     * @throws {iCloudSyncError} iCloud 不可用或 CloudKit 写入失败时的错误
     */
    func pushToCloud(pages: [WikiPage], logEntries: [LogEntry]) async throws {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }

        await MainActor.run { syncStatus = .syncing }

        do {
            // 确保自定义 Zone 存在
            try await ensureZoneExists()

            // 序列化数据
            let pagesData = try JSONEncoder().encode(pages)
            let logsData = try JSONEncoder().encode(logEntries)

            // 创建或获取现有记录
            let recordID = CKRecord.ID(recordName: "knowledge-management_main", zoneID: zoneID)
            let record: CKRecord

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

    // MARK: - 云端拉取
    
    /**
     * @description: 从 iCloud 拉取最新数据
     * @return { ([WikiPage], [LogEntry]) } 返回拉取到的页面和日志元组
     * @throws {iCloudSyncError} iCloud 不可用或 CloudKit 读取失败时的错误
     */
    func pullFromCloud() async throws -> ([WikiPage], [LogEntry]) {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }

        await MainActor.run { syncStatus = .syncing }

        do {
            try await ensureZoneExists()

            let recordID = CKRecord.ID(recordName: "knowledge-management_main", zoneID: zoneID)
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
            // 记录尚不存在，返回空数据
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

    // MARK: - 双向全量同步
    
    /**
     * @description: 执行完整的双向同步：拉取远程记录 -> 比对冲突 -> 合并数据 -> 推送回云端
     * @param { [WikiPage] } localPages 本地页面数据
     * @param { [LogEntry] } localLogs 本地日志数据
     * @return { ([WikiPage], [LogEntry]) } 返回合并后的最终数据集
     * @throws {iCloudSyncError} 同步链路任何环节失败时的错误
     */
    func sync(localPages: [WikiPage], localLogs: [LogEntry]) async throws -> ([WikiPage], [LogEntry]) {
        guard iCloudAvailable, let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }

        await MainActor.run { syncStatus = .syncing }

        do {
            try await ensureZoneExists()

            // 1. 获取远程记录
            let (remotePages, remoteLogs, record) = try await fetchRemoteData(database: database)

            // 2. 解决冲突
            let (finalPages, finalLogs) = try await resolveSyncConflict(
                localPages: localPages,
                localLogs: localLogs,
                remotePages: remotePages,
                remoteLogs: remoteLogs,
                record: record
            )

            // 3. 推送合并后的数据
            try await pushToCloud(database: database, record: record, pages: finalPages, logs: finalLogs)

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

    /**
     * @description: 从指定数据库中获取远程记录
     * @param {CKDatabase} database 云端数据库实例
     * @return { ([WikiPage], [LogEntry], CKRecord) } 远程数据与 CKRecord 对象的元组
     */
    private func fetchRemoteData(database: CKDatabase) async throws -> ([WikiPage], [LogEntry], CKRecord) {
        let recordID = CKRecord.ID(recordName: "knowledge-management_main", zoneID: zoneID)
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

        return (remotePages, remoteLogs, record)
    }

    /**
     * @description: 执行核心冲突比对逻辑，基于 LWW 策略或用户策略决定最终版本
     * @param { [WikiPage] } localPages 本地页面数据
     * @param { [LogEntry] } localLogs 本地日志数据
     * @param { [WikiPage] } remotePages 远程页面数据
     * @param { [LogEntry] } remoteLogs 远程日志数据
     * @param {CKRecord} record 云端记录对象
     * @return { ([WikiPage], [LogEntry]) } 冲突解决后的最终数据集
     */
    private func resolveSyncConflict(
        localPages: [WikiPage],
        localLogs: [LogEntry],
        remotePages: [WikiPage],
        remoteLogs: [LogEntry],
        record: CKRecord
    ) async throws -> ([WikiPage], [LogEntry]) {
        var finalPages = localPages
        var finalLogs = localLogs

        guard !remotePages.isEmpty else {
            return (finalPages, finalLogs)
        }

        let remoteDate = record["lastModified"] as? Date ?? Date.distantPast
        let hasRemoteNewer = lastSyncDate.map { remoteDate > $0 } ?? true

        if hasRemoteNewer {
            // 检测到冲突：应用冲突解决策略
            let resolution = await resolveConflict(
                localPages: localPages,
                localLogs: localLogs,
                remotePages: remotePages,
                remoteLogs: remoteLogs
            )

            switch resolution {
            case .keepLocal:
                break
            case .keepRemote:
                finalPages = remotePages
                finalLogs = remoteLogs
            case .merge:
                finalPages = mergePages(local: localPages, remote: remotePages)
                finalLogs = mergeLogs(local: localLogs, remote: remoteLogs)
            }
        } else if lastSyncDate != nil {
            // 云端版本较旧或无变动
            finalPages = localPages
            finalLogs = localLogs
        }

        return (finalPages, finalLogs)
    }

    /**
     * @description: 执行物理推送动作，将合并后的数据块序列化并存入记录
     * @param {CKDatabase} database 云端数据库实例
     * @param {CKRecord} record 云端记录对象
     * @param { [WikiPage] } pages 最终页面数据
     * @param { [LogEntry] } logs 最终日志数据
     * @return {*}
     */
    private func pushToCloud(database: CKDatabase, record: CKRecord, pages: [WikiPage], logs: [LogEntry]) async throws {
        let mergedPagesData = try JSONEncoder().encode(pages)
        let mergedLogsData = try JSONEncoder().encode(logs)

        record["pagesData"] = mergedPagesData as CKRecordValue
        record["logEntriesData"] = mergedLogsData as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue

        _ = try await database.save(record)
    }

    /**
     * @description: 订阅云端变更通知，实现静默推送更新
     * @return {*}
     */
    func subscribeToRemoteChanges() async throws {
        guard let database else {
            throw iCloudSyncError.iCloudNotAvailable
        }
        let subscription = CKDatabaseSubscription(subscriptionID: "knowledge-management_all_changes")

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await database.save(subscription)
    }

    /**
     * @description: 手动触发从云端获取变更，通常由推送通知触发
     * @return { ([WikiPage], [LogEntry]) } 获取到的最新数据
     */
    func fetchRemoteChanges() async throws -> ([WikiPage], [LogEntry]) {
        return try await pullFromCloud()
    }

    /**
     * @description: 确保专有区域（Custom Zone）存在，若不存在则进行创建
     * @return {*}
     */
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

    /**
     * @description: 调度冲突解决策略，优先咨询外部回调，若无回调则默认合并
     * @param { [WikiPage] } localPages 本地页面数据
     * @param { [LogEntry] } localLogs 本地日志数据
     * @param { [WikiPage] } remotePages 远程页面数据
     * @param { [LogEntry] } remoteLogs 远程日志数据
     * @return {ConflictResolution} 选定的解决策略
     */
    private func resolveConflict(
        localPages: [WikiPage],
        localLogs: [LogEntry],
        remotePages: [WikiPage],
        remoteLogs: [LogEntry]
    ) async -> ConflictResolution {
        // 若设置了回调，询问调用方
        if let onConflict = onConflictDetected {
            return onConflict(localPages, localLogs, remotePages, remoteLogs)
        }
        // 默认执行合并
        return .merge
    }

    // MARK: - 合并策略实现
    
    /**
     * @description: 对页面列表执行智能合并，相同 ID 以最新时间戳为准，新页面自动追加
     * @param { [WikiPage] } local 本地页面列表
     * @param { [WikiPage] } remote 远程页面列表
     * @return {[WikiPage]} 合并后的页面列表
     */
    private func mergePages(local: [WikiPage], remote: [WikiPage]) -> [WikiPage] {
        var merged = local

        for remotePage in remote {
            if let localIndex = merged.firstIndex(where: { $0.id == remotePage.id }) {
                // ID 冲突：保留较新版本
                let localPage = merged[localIndex]
                if remotePage.updated > localPage.updated {
                    merged[localIndex] = remotePage
                }
            } else if !merged.contains(where: { $0.title == remotePage.title }) {
                // 新的远程页面：追加
                merged.append(remotePage)
            }
        }

        return merged
    }

    /**
     * @description: 对日志记录执行合并，通过 ID 去重并保留最近 200 条记录
     * @param { [LogEntry] } local 本地日志列表
     * @param { [LogEntry] } remote 远程日志列表
     * @return {[LogEntry]} 合并后的日志列表
     */
    private func mergeLogs(local: [LogEntry], remote: [LogEntry]) -> [LogEntry] {
        var merged = local

        for remoteLog in remote {
            if !merged.contains(where: { $0.id == remoteLog.id }) {
                merged.append(remoteLog)
            }
        }

        // 按日期排序
        merged.sort { $0.timestamp > $1.timestamp }

        // 仅保留最近 200 条
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
        case .keepLocal: return L10n.ICloud.tr("keepLocal")
        case .keepRemote: return L10n.ICloud.tr("keepRemote")
        case .merge: return L10n.ICloud.tr("merge")
        }
    }
}

@MainActor
extension iCloudSyncService: @unchecked Sendable {}
#endif // ICLOUD_ENABLED
