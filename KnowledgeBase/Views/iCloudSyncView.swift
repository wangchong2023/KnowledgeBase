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
                            Text("上次同步：\(date.formatted(.dateTime.year().month().day().hour().minute()))")
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
                Text("iCloud 同步状态")
            }
            
            // MARK: - Actions Section
            Section {
                // Push to iCloud
                Button(action: pushToCloud) {
                    Label("上传到 iCloud", systemImage: "icloud.and.arrow.up")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("push-to-icloud")
                .disabled(!syncService.iCloudAvailable || isSyncing)

                // Pull from iCloud
                Button(action: { showPullConfirmation = true }) {
                    Label("从 iCloud 下载", systemImage: "icloud.and.arrow.down")
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("pull-from-icloud")
                .disabled(!syncService.iCloudAvailable || isSyncing)
                
                // Bidirectional sync
                Button(action: bidirectionalSync) {
                    Label("双向同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                        .foregroundStyle(.wikiAccent)
                }
                .disabled(!syncService.iCloudAvailable || isSyncing)
            } header: {
                Text("同步操作")
            }
            
            // MARK: - Settings Section
            Section {
                Toggle("自动同步", isOn: $autoSync)
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
                    Text("冲突解决策略")
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
                Text("同步设置")
            }
            
            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SyncInfoRow(icon: "1.circle.fill", text: "数据通过 iCloud 私有数据库存储")
                    SyncInfoRow(icon: "2.circle.fill", text: "仅限同一 Apple ID 的设备间同步")
                    SyncInfoRow(icon: "3.circle.fill", text: "冲突时默认合并两边数据")
                    SyncInfoRow(icon: "4.circle.fill", text: "页面以更新时间为准，保留较新版本")
                }
                .padding(.vertical, 4)
            } header: {
                Text("关于 iCloud 同步")
            }
            
            // MARK: - Danger Section
            Section {
                Button(role: .destructive) {
                    clearCloudData()
                } label: {
                    Label("清除 iCloud 数据", systemImage: "trash.icloud")
                        .foregroundStyle(.red)
                }
                .disabled(isSyncing)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle("iCloud 同步")
        .alert("同步错误", isPresented: $showError) {
            Button("确定", role: .cancel) {}
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
            Button("取消", role: .cancel) {}
        } message: {
            Text("本地与远程数据存在冲突，请选择解决方式。")
        }
        .alert("从 iCloud 下载将覆盖本地数据", isPresented: $showPullConfirmation) {
            Button("下载", role: .destructive) {
                performActualPull()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有本地页面将被远程数据替换，此操作不可撤销。")
        }
        .alert("自动同步失败", isPresented: $showAutoSyncError) {
            Button("确定", role: .cancel) {}
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
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
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
                store.resetAllData()
                for page in finalPages {
                    store.addImportedPage(page)
                }
                store.saveToDisk()
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
                        // Replace local data with remote
                        store.resetAllData()
                        for page in pages {
                            store.addImportedPage(page)
                        }
                        store.saveToDisk()
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
                    // Update store with merged data
                    store.resetAllData()
                    for page in finalPages {
                        store.addImportedPage(page)
                    }
                    store.saveToDisk()
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
