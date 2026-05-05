// LogView.swift
//
// 作者: Wang Chong
// 功能说明: struct LogView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Log View (entry point with NavigationStack)
struct LogView: View {
    var body: some View {
        LogViewContent()
    }
}

// MARK: - Log View Content (for use inside parent NavigationStack)
struct LogViewContent: View {
    @Environment(KMStore.self) var store
    @State private var expandedEntryIDs: Set<UUID> = []
    @State private var showConfirmation = false

    var body: some View {
        List {
            if store.logEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.wikiSecondary)
                    Text(Localized.tr("log.noLogs"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                    Text(Localized.tr("log.noLogs"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(store.logEntries) { entry in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if expandedEntryIDs.contains(entry.id) {
                                expandedEntryIDs.remove(entry.id)
                            } else {
                                expandedEntryIDs.insert(entry.id)
                            }
                        }
                    }) {
                        LogEntryRow(
                            entry: entry,
                            isExpanded: expandedEntryIDs.contains(entry.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(L10n.Settings.tr("operationLog"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label(L10n.Common.tr("clear"), systemImage: "trash.slash.fill")
                }
            }
        }
        .confirmationDialog(
            Localized.tr("log.clearConfirmTitle"),
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.tr("clearAll"), role: .destructive) {
                HapticFeedback.shared.trigger(.warning)
                store.clearLogs()
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.Settings.tr("clearAll.message"))
        }
#if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.wikiBackground, for: .navigationBar)
#endif
    }
}

// MARK: - Log Entry Row
private struct LogEntryRow: View {
    let entry: LogEntry
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // 动作图标
                ZStack {
                    Circle()
                        .fill(entry.action.color.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: entry.action.icon)
                        .foregroundStyle(entry.action.color)
                        .font(.system(size: 14, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.action.localizedName)
                            .font(.headline)
                            .foregroundStyle(entry.action.color)
                        
                        Text(entry.target)
                            .font(.headline)
                            .foregroundStyle(.wikiText)
                            .lineLimit(1)
                    }
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !entry.details.isEmpty {
                        Text(entry.details)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.wikiSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.wikiBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text(Localized.tr("log.noDetails"))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary.opacity(0.6))
                    }
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

}
