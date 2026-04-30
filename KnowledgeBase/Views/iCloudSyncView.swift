import SwiftUI

// MARK: - iCloud Sync Settings View
struct iCloudSyncView: View {
    @ObservedObject var syncService: iCloudSyncService
    @ObservedObject var store: KMStore
    
    @State private var isSyncing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showConflictAlert = false
    @State private var showPullConfirmation = false
    @State private var showAutoSyncError = false
    @State private var autoSyncErrorMessage = ""
    @State private var conflictResolution: ConflictResolution = {
        if let raw = UserDefaults.standard.string(forKey: "wikicraft_conflict_resolution"),
           let resolved = ConflictResolution(rawValue: raw) {
            return resolved
        }
        return .merge
    }()
    @State private var autoSync = UserDefaults.standard.bool(forKey: "wikicraft_auto_sync")
    @State private var autoSyncTimer: Timer?
    
    // MARK: - Constants
    /// Auto-sync interval in seconds (5 minutes)
    private static let autoSyncInterval: TimeInterval = 300
    
    var body: some View {
        List {
            // MARK: - Status Section
            Section {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(syncService.syncStatus.label)
                            .font(.subheadline)
                            .foregroundStyle(.wikiText)
                        
                        if let date = syncService.lastSyncDate {
                            Text(L.trf("icloud.lastSyncFormat", date.formatted(.dateTime.year().month().day().hour().minute())))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if syncService.syncStatus.isSyncing {
                        ProgressView()
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.tr("icloud.syncStatus"))
            }
            
            // MARK: - Actions Section
            Section {
                // Push to iCloud
                Button(action: pushToCloud) {
                    Label(L.tr("icloud.pushToCloud"), systemImage: "icloud.and.arrow.up")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("push-to-icloud")
                .disabled(!syncService.iCloudAvailable || isSyncing)

                // Pull from iCloud
                Button(action: { showPullConfirmation = true }) {
                    Label(L.tr("icloud.pullFromCloud"), systemImage: "icloud.and.arrow.down")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("pull-from-icloud")
                .disabled(!syncService.iCloudAvailable || isSyncing)
                
                // Bidirectional sync
                Button(action: bidirectionalSync) {
                    Label(L.tr("icloud.bidirectionalSync"), systemImage: "arrow.triangle.2.circlepath.icloud")
                        .foregroundStyle(.wikiAccent)
                }
                .disabled(!syncService.iCloudAvailable || isSyncing)
            } header: {
                Text(L.tr("icloud.syncActions"))
            }
            
            // MARK: - Settings Section
            Section {
                Toggle(L.tr("icloud.autoSync"), isOn: $autoSync)
                    .foregroundStyle(.wikiText)
                    .accessibilityIdentifier("auto-sync")
                    .onChange(of: autoSync) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "wikicraft_auto_sync")
                        if newValue {
                            startAutoSyncIfNeeded()
                        } else {
                            autoSyncTimer?.invalidate()
                            autoSyncTimer = nil
                        }
                    }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.tr("icloud.conflictPolicy"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiText)
                    
                    Picker("", selection: $conflictResolution) {
                        ForEach(ConflictResolution.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: conflictResolution) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "wikicraft_conflict_resolution")
                    }
                }
            } header: {
                Text(L.tr("icloud.syncSettings"))
            }
            
            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SyncInfoRow(icon: "1.circle.fill", text: L.tr("icloud.info1"))
                    SyncInfoRow(icon: "2.circle.fill", text: L.tr("icloud.info2"))
                    SyncInfoRow(icon: "3.circle.fill", text: L.tr("icloud.info3"))
                    SyncInfoRow(icon: "4.circle.fill", text: L.tr("icloud.info4"))
                }
                .padding(.vertical, 4)
            } header: {
                Text(L.tr("icloud.aboutSync"))
            }
            
            // MARK: - Danger Section
            Section {
                Button(role: .destructive) {
                    clearCloudData()
                } label: {
                    Label(L.tr("icloud.clearCloudData"), systemImage: "trash.icloud")
                        .foregroundStyle(.red)
                }
                .disabled(isSyncing)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(L.tr("icloud.title"))
        .alert(L.tr("icloud.syncError"), isPresented: $showError) {
            Button(L.tr("misc.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(L.tr("icloud.conflictDetected"), isPresented: $showConflictAlert) {
            Button(ConflictResolution.merge.displayName) {
                conflictResolution = .merge
                UserDefaults.standard.set(ConflictResolution.merge.rawValue, forKey: "wikicraft_conflict_resolution")
            }
            Button(ConflictResolution.keepLocal.displayName) {
                conflictResolution = .keepLocal
                UserDefaults.standard.set(ConflictResolution.keepLocal.rawValue, forKey: "wikicraft_conflict_resolution")
            }
            Button(ConflictResolution.keepRemote.displayName) {
                conflictResolution = .keepRemote
                UserDefaults.standard.set(ConflictResolution.keepRemote.rawValue, forKey: "wikicraft_conflict_resolution")
            }
            Button(L.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(L.tr("icloud.conflictMessage"))
        }
        .alert(L.tr("icloud.pullWillOverwrite"), isPresented: $showPullConfirmation) {
            Button(L.tr("icloud.download"), role: .destructive) {
                performActualPull()
            }
            Button(L.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(L.tr("icloud.pullOverwriteMessage"))
        }
        .alert(L.tr("icloud.autoSyncFailed"), isPresented: $showAutoSyncError) {
            Button(L.tr("misc.ok"), role: .cancel) {}
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
    
    // MARK: - Computed
    private var statusIcon: String {
        switch syncService.syncStatus {
        case .idle: return "icloud"
        case .syncing: return "icloud.and.arrow.up.and.down"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }
    
    private var statusColor: Color {
        switch syncService.syncStatus {
        case .idle: return .wikiSecondary
        case .syncing: return .wikiAccent
        case .synced: return .green
        case .error: return .red
        }
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
        store.resetAllData()
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

// MARK: - Sync Info Row
private struct SyncInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.wikiAccent)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
    }
}
