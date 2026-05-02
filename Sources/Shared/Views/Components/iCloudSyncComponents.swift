import SwiftUI

// MARK: - Sync Status Row
/// iCloud 同步状态行：图标 + 状态文字 + 上次同步时间
struct SyncStatusRow: View {
    let syncService: iCloudSyncService

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

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(syncService.syncStatus.label)
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)

                if let date = syncService.lastSyncDate {
                    Text(Localized.trf("icloud.lastSyncFormat", date.formatted(.dateTime.year().month().day().hour().minute())))
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
    }
}

// MARK: - Sync Actions Section
/// iCloud 同步操作区：推送到云端 / 从云端拉取 / 双向同步
struct SyncActionsSection: View {
    let syncService: iCloudSyncService
    let isSyncing: Bool

    let onPush: () -> Void
    let onPullRequest: () -> Void
    let onBidirectional: () -> Void

    var body: some View {
        Section {
            // Push to iCloud
            Button(action: onPush) {
                Label(Localized.tr("icloud.pushToCloud"), systemImage: "icloud.and.arrow.up")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("push-to-icloud")
            .disabled(!syncService.iCloudAvailable || isSyncing)

            // Pull from iCloud
            Button(action: onPullRequest) {
                Label(Localized.tr("icloud.pullFromCloud"), systemImage: "icloud.and.arrow.down")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("pull-from-icloud")
            .disabled(!syncService.iCloudAvailable || isSyncing)

            // Bidirectional sync
            Button(action: onBidirectional) {
                Label(Localized.tr("icloud.bidirectionalSync"), systemImage: "arrow.triangle.2.circlepath.icloud")
                    .foregroundStyle(.wikiText)
            }
            .disabled(!syncService.iCloudAvailable || isSyncing)
        } header: {
            Text(Localized.tr("icloud.syncActions"))
        }
    }
}

// MARK: - Sync Settings Section
/// iCloud 自动同步和冲突解决策略设置
struct SyncSettingsSection: View {
    @Binding var autoSync: Bool
    @Binding var conflictResolution: ConflictResolution

    let onAutoSyncChange: (Bool) -> Void

    var body: some View {
        Section {
            Toggle(Localized.tr("icloud.autoSync"), isOn: $autoSync)
                .foregroundStyle(.wikiText)
                .accessibilityIdentifier("auto-sync")
                .onChange(of: autoSync) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "knowledge-management_auto_sync")
                    onAutoSyncChange(newValue)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(Localized.tr("icloud.conflictPolicy"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)

                Picker("", selection: $conflictResolution) {
                    ForEach(ConflictResolution.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: conflictResolution) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "knowledge-management_conflict_resolution")
                }
            }
        } header: {
            Text(Localized.tr("icloud.syncSettings"))
        }
    }
}

// MARK: - Sync Info Row
/// iCloud 说明信息行
struct SyncInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.wikiText)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
    }
}
