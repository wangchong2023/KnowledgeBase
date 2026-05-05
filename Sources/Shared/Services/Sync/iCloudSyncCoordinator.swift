// iCloudSyncCoordinator.swift
//
// 作者: Wang Chong
// 功能说明: 负责 iCloud 同步的业务编排，将 View 层的同步逻辑提取到服务层。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

#if ICLOUD_ENABLED
import Foundation
import Observation

// MARK: - iCloud Sync Coordinator
/// 负责 iCloud 同步的业务编排，将 View 层的同步逻辑提取到服务层。
@MainActor
@Observable
final class iCloudSyncCoordinator {
    let syncService: iCloudSyncService
    var store: KMStore?
    var settingsStore: SettingsStore?

    // MARK: - UI State
    var isSyncing = false
    var showError = false
    var errorMessage = ""
    var showConflictAlert = false
    var showPullConfirmation = false
    var showClearCloudConfirmation = false
    var showAutoSyncError = false
    var autoSyncErrorMessage = ""
    var conflictResolution: ConflictResolution = .merge
    var autoSync = false

    private var autoSyncTimer: Timer?
    private static let autoSyncInterval: TimeInterval = 300

    var iCloudAvailable: Bool { syncService.iCloudAvailable }
    var syncStatus: SyncStatus { syncService.syncStatus }

    init(syncService: iCloudSyncService = iCloudSyncService()) {
        self.syncService = syncService
    }

    // MARK: - Lifecycle

    func onAppear() {
        if let raw = settingsStore?.iCloudConflictResolution,
           let resolved = ConflictResolution(rawValue: raw) {
            conflictResolution = resolved
        }
        autoSync = settingsStore?.iCloudAutoSync ?? false
        startAutoSyncIfNeeded()
    }

    func onDisappear() {
        cancelAutoSync()
    }

    // MARK: - Auto Sync

    func startAutoSyncIfNeeded() {
        autoSyncTimer?.invalidate()
        guard autoSync, syncService.iCloudAvailable else { return }

        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: Self.autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !isSyncing else { return }
                await performAutoSync()
            }
        }

        Task { @MainActor [weak self] in
            guard let self, !isSyncing else { return }
            await performAutoSync()
        }
    }

    func cancelAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    private func performAutoSync() async {
        guard let store else { return }
        isSyncing = true
        syncService.onConflictDetected = { [weak self] _, _, _, _ in
            self?.conflictResolution ?? .merge
        }

        do {
            let (finalPages, _) = try await syncService.sync(
                localPages: store.pages,
                localLogs: store.logEntries
            )
            if !finalPages.isEmpty {
                replaceLocalData(with: finalPages)
            }
        } catch {
            autoSyncErrorMessage = error.localizedDescription
            showAutoSyncError = true
        }
        isSyncing = false
    }

    // MARK: - Sync Actions

    func pushToCloud() {
        guard let store else { return }
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await syncService.pushToCloud(pages: store.pages, logEntries: store.logEntries)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    func pullFromCloud() {
        guard store != nil else { return }
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let (pages, _) = try await syncService.pullFromCloud()
                if !pages.isEmpty {
                    replaceLocalData(with: pages)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    func bidirectionalSync() {
        guard let store else { return }
        isSyncing = true
        syncService.onConflictDetected = { [weak self] _, _, _, _ in
            self?.conflictResolution ?? .merge
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (finalPages, _) = try await syncService.sync(
                    localPages: store.pages,
                    localLogs: store.logEntries
                )
                replaceLocalData(with: finalPages)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    func clearCloudData() {
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await syncService.pushToCloud(pages: [], logEntries: [])
                syncService.syncStatus = .idle
                syncService.lastSyncDate = nil
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    // MARK: - Data Management

    func replaceLocalData(with pages: [WikiPage]) {
        guard let store else { return }
        try? store.clearAllData()
        for page in pages {
            store.addImportedPage(page)
        }
        store.saveToDisk()
    }
}
#endif // ICLOUD_ENABLED
