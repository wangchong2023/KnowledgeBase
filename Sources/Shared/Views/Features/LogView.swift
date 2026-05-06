// LogView.swift
//
// 作者: Wang Chong
// 功能说明: struct LogView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 导航入口
/// 操作日志主视图容器
/// 负责为日志内容提供独立的导航堆栈，支持在设置页或侧边栏中嵌入
struct LogView: View {
    var body: some View {
        LogViewContent()
    }
}

// MARK: - 视图核心
/// 操作日志核心内容列表视图
/// 负责从存储引擎加载日志条目，处理清空逻辑，并管理条目的展开/折叠状态
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

// MARK: - 日志项渲染
/// 日志条目行渲染组件
/// 负责展示单条日志的动词、目标对象、模块、时间戳，并在展开时显示耗时详情与原始元数据
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
                        
                        if let mod = entry.module {
                            Text(mod)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.wikiSecondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.wikiSecondary)
                        }
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
                VStack(alignment: .leading, spacing: 12) {
                    // 时间详情
                    HStack(spacing: 20) {
                        if let start = entry.startTime {
                            VStack(alignment: .leading) {
                                Text(Localized.tr("log.startTime"))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                                Text(start.formatted(date: .omitted, time: .standard))
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                        
                        if let end = entry.endTime {
                            VStack(alignment: .leading) {
                                Text(Localized.tr("log.endTime"))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                                Text(end.formatted(date: .omitted, time: .standard))
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                        
                        if let dur = entry.duration {
                            VStack(alignment: .leading) {
                                Text(Localized.tr("log.duration"))
                                    .font(.caption2)
                                    .foregroundStyle(.wikiSecondary)
                                Text(String(format: "%.2fs", dur))
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .foregroundStyle(.wikiAccent)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.wikiCard.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    if !entry.details.isEmpty {
                        Text(entry.details)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.wikiSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.wikiBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

}
