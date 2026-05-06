// iCloudSyncComponents.swift
//
// 作者: Wang Chong
// 功能说明: iCloud 同步状态行：图标 + 状态文字 + 上次同步时间
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

#if ICLOUD_ENABLED
import SwiftUI

// MARK: - Sync Status Row
/// iCloud 同步状态行：图标 + 状态文字 + 上次同步时间
/// iCloud 同步状态展示行组件
/// 负责实时展示与云端同步的健康度、进度及最后一次成功同步的时间戳
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
/// iCloud 同步手动操作区域组件
/// 负责提供上传本地、拉取云端及双向合并等显式同步指令的交互入口
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
                Label(L10n.ICloud.tr("pushToCloud"), systemImage: "icloud.and.arrow.up")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("push-to-icloud")
            .disabled(!syncService.iCloudAvailable || isSyncing)

            // Pull from iCloud
            Button(action: onPullRequest) {
                Label(L10n.ICloud.tr("pullFromCloud"), systemImage: "icloud.and.arrow.down")
                    .foregroundStyle(.wikiText)
            }
            .accessibilityIdentifier("pull-from-icloud")
            .disabled(!syncService.iCloudAvailable || isSyncing)

            // Bidirectional sync
            Button(action: onBidirectional) {
                Label(L10n.ICloud.tr("bidirectionalSync"), systemImage: "arrow.triangle.2.circlepath.icloud")
                    .foregroundStyle(.wikiText)
            }
            .disabled(!syncService.iCloudAvailable || isSyncing)
        } header: {
            Text(L10n.ICloud.tr("syncActions"))
        }
    }
}

// MARK: - Sync Settings Section
/// iCloud 自动同步和冲突解决策略设置
/// iCloud 同步策略配置区域组件
/// 负责配置自动同步开关及版本冲突时的解决策略（如保留云端、保留本地或按时间戳合并）
struct SyncSettingsSection: View {
    @Binding var autoSync: Bool
    @Binding var conflictResolution: ConflictResolution

    let onAutoSyncChange: (Bool) -> Void

    var body: some View {
        Section {
            Toggle(L10n.ICloud.tr("autoSync"), isOn: $autoSync)
                .foregroundStyle(.wikiText)
                .accessibilityIdentifier("auto-sync")
                .onChange(of: autoSync) { _, newValue in
                    onAutoSyncChange(newValue)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.ICloud.tr("conflictPolicy"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiText)

                Picker("", selection: $conflictResolution) {
                    ForEach(ConflictResolution.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text(L10n.ICloud.tr("syncSettings"))
        }
    }
}

// MARK: - Sync Info Row
/// iCloud 说明信息行
/// iCloud 同步信息提示行组件
/// 负责展示有关云同步的安全提示或功能局限性说明，提升用户信任感
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
#endif // ICLOUD_ENABLED
