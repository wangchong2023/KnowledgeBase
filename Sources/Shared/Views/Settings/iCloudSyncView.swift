@preconcurrency import SwiftUI

// MARK: - iCloud Sync Settings View
struct iCloudSyncView: View {
    @ObservedObject var syncService: iCloudSyncService
    var store: KMStore
    
    @State private var isSyncing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showConflictAlert = false
    @State private var showPullConfirmation = false
    @State private var showClearCloudConfirmation = false
    @State private var showAutoSyncError = false
    @State private var autoSyncErrorMessage = ""
    @State private var conflictResolution: ConflictResolution = {
        if let raw = UserDefaults.standard.string(forKey: "knowledge-management_conflict_resolution"),
           let resolved = ConflictResolution(rawValue: raw) {
            return resolved
        }
        return .merge
    }()
    @State private var autoSync = UserDefaults.standard.bool(forKey: "knowledge-management_auto_sync")
    @State private var autoSyncTimer: Timer?
    
    // MARK: - Constants
    /// Auto-sync interval in seconds (5 minutes)
    private static let autoSyncInterval: TimeInterval = 300
    
    var body: some View {
        List {
            // MARK: - Status Section
            Section {
                SyncStatusRow(syncService: syncService)
            } header: {
                Text(Localized.tr("icloud.syncStatus"))
            }

            // MARK: - Actions Section
            SyncActionsSection(
                syncService: syncService,
                isSyncing: isSyncing,
                onPush: pushToCloud,
                onPullRequest: { showPullConfirmation = true },
                onBidirectional: bidirectionalSync
            )

            // MARK: - Settings Section
            SyncSettingsSection(
                autoSync: $autoSync,
                conflictResolution: $conflictResolution,
                onAutoSyncChange: { enabled in
                    if enabled {
                        startAutoSyncIfNeeded()
                    } else {
                        autoSyncTimer?.invalidate()
                        autoSyncTimer = nil
                    }
                }
            )
            
            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SyncInfoRow(icon: "1.circle.fill", text: Localized.tr("icloud.info1"))
                    SyncInfoRow(icon: "2.circle.fill", text: Localized.tr("icloud.info2"))
                    SyncInfoRow(icon: "3.circle.fill", text: Localized.tr("icloud.info3"))
                    SyncInfoRow(icon: "4.circle.fill", text: Localized.tr("icloud.info4"))
                }
                .padding(.vertical, 4)
            } header: {
                Text(Localized.tr("icloud.aboutSync"))
            }
            
            // MARK: - Danger Section
            Section {
                Button(role: .destructive) {
                    showClearCloudConfirmation = true
                } label: {
                    Label(Localized.tr("icloud.clearCloudData"), systemImage: "trash.icloud")
                        .foregroundStyle(.red)
                }
                .disabled(isSyncing)
            }
        }
#if os(iOS)
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
#endif
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("icloud.title"))
        .alert(Localized.tr("icloud.syncError"), isPresented: $showError) {
            Button(Localized.tr("misc.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(Localized.tr("icloud.conflictDetected"), isPresented: $showConflictAlert) {
            Button(ConflictResolution.merge.displayName) {
                conflictResolution = .merge
                UserDefaults.standard.set(ConflictResolution.merge.rawValue, forKey: "knowledge-management_conflict_resolution")
            }
            Button(ConflictResolution.keepLocal.displayName) {
                conflictResolution = .keepLocal
                UserDefaults.standard.set(ConflictResolution.keepLocal.rawValue, forKey: "knowledge-management_conflict_resolution")
            }
            Button(ConflictResolution.keepRemote.displayName) {
                conflictResolution = .keepRemote
                UserDefaults.standard.set(ConflictResolution.keepRemote.rawValue, forKey: "knowledge-management_conflict_resolution")
            }
            Button(Localized.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("icloud.conflictMessage"))
        }
        .confirmationDialog(Localized.tr("icloud.pullWillOverwrite"), isPresented: $showPullConfirmation, titleVisibility: .visible) {
            Button(Localized.tr("icloud.download"), role: .destructive) {
                performActualPull()
            }
            Button(Localized.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("icloud.pullOverwriteMessage"))
        }
        .confirmationDialog(Localized.tr("icloud.clearCloudData"), isPresented: $showClearCloudConfirmation, titleVisibility: .visible) {
            Button(Localized.tr("misc.clearAll"), role: .destructive) {
                clearCloudData()
                HapticManager.shared.trigger(.success)
            }
            Button(Localized.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(Localized.tr("icloud.clearCloudDataMessage")) // 确保 Localized 有此 Key
        }
        .alert(Localized.tr("icloud.autoSyncFailed"), isPresented: $showAutoSyncError) {
            Button(Localized.tr("misc.ok"), role: .cancel) {}
        } message: {
            Text(autoSyncErrorMessage)
        }
        .onAppear {
            startAutoSyncIfNeeded()
        }
        .onDisappear {
            autoSyncTimer?.invalidate()
            autoSyncTimer = nil
        }
    }
    
    // MARK: - Auto Sync
    private func startAutoSyncIfNeeded() {
        autoSyncTimer?.invalidate()
        guard autoSync, syncService.iCloudAvailable else { return }
        
        // Auto-sync every 5 minutes
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: Self.autoSyncInterval, repeats: true) { _ in
            Task { @MainActor in
                guard !isSyncing else { return }
                await performAutoSync()
            }
        }
        
        // Also perform an immediate sync on appear
        Task { @MainActor in
            guard !isSyncing else { return }
            await performAutoSync()
        }
    }
    
    private func performAutoSync() async {
        isSyncing = true
        syncService.onConflictDetected = { _, _, _, _ in
            return conflictResolution
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
            await MainActor.run {
                autoSyncErrorMessage = error.localizedDescription
                showAutoSyncError = true
            }
        }
        isSyncing = false
    }
    
    // MARK: - Actions
    private func pushToCloud() {
        isSyncing = true
        Task {
            do {
                try await syncService.pushToCloud(pages: store.pages, logEntries: store.logEntries)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSyncing = false }
        }
    }
    
    private func pullFromCloud() {
        isSyncing = true
        Task {
            do {
                let (pages, _) = try await syncService.pullFromCloud()
                await MainActor.run {
                    if !pages.isEmpty {
                        replaceLocalData(with: pages)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSyncing = false }
        }
    }

    private func performActualPull() {
        pullFromCloud()
    }
    
    private func bidirectionalSync() {
        isSyncing = true
        syncService.onConflictDetected = { _, _, _, _ in
            // In UI context, return the user's chosen resolution
            return conflictResolution
        }
        
        Task {
            do {
                let (finalPages, _) = try await syncService.sync(
                    localPages: store.pages,
                    localLogs: store.logEntries
                )
                await MainActor.run {
                    replaceLocalData(with: finalPages)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSyncing = false }
        }
    }
    
    // MARK: - Helpers
    /// Replaces all local data with imported pages from sync results.
    private func replaceLocalData(with pages: [WikiPage]) {
        try? store.clearAllData()
        for page in pages {
            store.addImportedPage(page)
        }
        store.saveToDisk()
    }
    
    private func clearCloudData() {
        isSyncing = true
        Task {
            do {
                try await syncService.pushToCloud(pages: [], logEntries: [])
                await MainActor.run {
                    syncService.syncStatus = .idle
                    syncService.lastSyncDate = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            await MainActor.run { isSyncing = false }
        }
    }
}
