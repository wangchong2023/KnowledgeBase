// iCloudSyncView.swift
//
// 作者: Wang Chong
// 功能说明: struct iCloudSyncView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

#if ICLOUD_ENABLED
@preconcurrency import SwiftUI

// MARK: - iCloud Sync Settings View
struct iCloudSyncView: View {
    @Environment(KMStore.self) var store
    @Environment(SettingsStore.self) var settingsStore

    @Bindable var coordinator: iCloudSyncCoordinator

    var body: some View {
        List {
            // MARK: - Status Section
            Section {
                SyncStatusRow(syncService: coordinator.syncService)
            } header: {
                Text(L10n.ICloud.tr("syncStatus"))
            }

            // MARK: - Actions Section
            SyncActionsSection(
                syncService: coordinator.syncService,
                isSyncing: coordinator.isSyncing,
                onPush: coordinator.pushToCloud,
                onPullRequest: { coordinator.showPullConfirmation = true },
                onBidirectional: coordinator.bidirectionalSync
            )

            // MARK: - Settings Section
            SyncSettingsSection(
                autoSync: $coordinator.autoSync,
                conflictResolution: $coordinator.conflictResolution,
                onAutoSyncChange: { enabled in
                    if enabled {
                        coordinator.startAutoSyncIfNeeded()
                    } else {
                        coordinator.cancelAutoSync()
                    }
                }
            )

            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SyncInfoRow(icon: "1.circle.fill", text: L10n.ICloud.tr("info1"))
                    SyncInfoRow(icon: "2.circle.fill", text: L10n.ICloud.tr("info2"))
                    SyncInfoRow(icon: "3.circle.fill", text: L10n.ICloud.tr("info3"))
                    SyncInfoRow(icon: "4.circle.fill", text: L10n.ICloud.tr("info4"))
                }
                .padding(.vertical, 4)
            } header: {
                Text(L10n.ICloud.tr("aboutSync"))
            }

            // MARK: - Danger Section
            Section {
                Button(role: .destructive) {
                    coordinator.showClearCloudConfirmation = true
                } label: {
                    Label(L10n.ICloud.tr("clearCloudData"), systemImage: "trash.icloud")
                        .foregroundStyle(.red)
                }
                .disabled(coordinator.isSyncing)
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(L10n.ICloud.tr("title"))
        .alert(L10n.ICloud.tr("syncError"), isPresented: $coordinator.showError) {
            Button(L10n.Common.tr("ok"), role: .cancel) {}
        } message: {
            Text(coordinator.errorMessage)
        }
        .alert(L10n.ICloud.tr("conflictDetected"), isPresented: $coordinator.showConflictAlert) {
            Button(ConflictResolution.merge.displayName) {
                coordinator.conflictResolution = .merge
                settingsStore.iCloudConflictResolution = ConflictResolution.merge.rawValue
            }
            Button(ConflictResolution.keepLocal.displayName) {
                coordinator.conflictResolution = .keepLocal
                settingsStore.iCloudConflictResolution = ConflictResolution.keepLocal.rawValue
            }
            Button(ConflictResolution.keepRemote.displayName) {
                coordinator.conflictResolution = .keepRemote
                settingsStore.iCloudConflictResolution = ConflictResolution.keepRemote.rawValue
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.ICloud.tr("conflictMessage"))
        }
        .confirmationDialog(L10n.ICloud.tr("pullWillOverwrite"), isPresented: $coordinator.showPullConfirmation, titleVisibility: .visible) {
            Button(L10n.ICloud.tr("download"), role: .destructive) {
                coordinator.pullFromCloud()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.ICloud.tr("pullOverwriteMessage"))
        }
        .confirmationDialog(L10n.ICloud.tr("clearCloudData"), isPresented: $coordinator.showClearCloudConfirmation, titleVisibility: .visible) {
            Button(L10n.Common.tr("clearAll"), role: .destructive) {
                coordinator.clearCloudData()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.ICloud.tr("clearCloudDataMessage"))
        }
        .alert(L10n.ICloud.tr("autoSyncFailed"), isPresented: $coordinator.showAutoSyncError) {
            Button(L10n.Common.tr("ok"), role: .cancel) {}
        } message: {
            Text(coordinator.autoSyncErrorMessage)
        }
        .onAppear {
            coordinator.store = store
            coordinator.settingsStore = settingsStore
            coordinator.onAppear()
        }
        .onChange(of: coordinator.autoSync) { _, newValue in
            settingsStore.iCloudAutoSync = newValue
        }
        .onChange(of: coordinator.conflictResolution) { _, newValue in
            settingsStore.iCloudConflictResolution = newValue.rawValue
        }
        .onDisappear {
            coordinator.onDisappear()
        }
    }
}
#endif // ICLOUD_ENABLED
