import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    @State private var expandedEntryIDs: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            List {
                if store.logEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.wikiSecondary)
                        Text(L.tr("log.noLogs"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text("创建、编辑、导入等操作会自动记录在此")
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("settings.operationLog"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("log.close")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Log Entry Row
private struct LogEntryRow: View {
    let entry: LogEntry
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row (always visible)
            HStack(spacing: 12) {
                Circle()
                    .fill(actionColor(entry.action))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: actionIcon(entry.action))
                            .font(.caption)
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.action)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(actionColor(entry.action))
                        
                        Text("·")
                            .foregroundStyle(.wikiSecondary)
                        
                        Text(entry.target)
                            .font(.caption)
                            .foregroundStyle(.wikiText)
                            .lineLimit(1)
                    }
                    
                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
            
            // Details (expanded)
            if isExpanded {
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                        .padding(.leading, 44)
                } else {
                    Text(L.tr("log.noDetails"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func actionColor(_ action: String) -> Color {
        switch action {
        case "创建", L.tr("logAction.create"): return .green
        case "更新", L.tr("logAction.update"): return .blue
        case "删除", L.tr("logAction.delete"): return .red
        case "Lint", L.tr("logAction.healthCheck"): return .orange
        case "导入", L.tr("logAction.ingest"): return .wikiSource
        case "智能导入": return .wikiAccent
        case "撤销操作", L.tr("logAction.undo"): return .purple
        case "重做操作", L.tr("logAction.redo"): return .purple
        case "同步": return .teal
        default: return .wikiSecondary
        }
    }
    
    private func actionIcon(_ action: String) -> String {
        switch action {
        case "创建", L.tr("logAction.create"): return "plus"
        case "更新", L.tr("logAction.update"): return "pencil"
        case "删除", L.tr("logAction.delete"): return "trash"
        case "Lint", L.tr("logAction.healthCheck"): return "stethoscope"
        case "导入", L.tr("logAction.ingest"): return "arrow.down.doc"
        case "智能导入": return "sparkles"
        case "撤销操作", L.tr("logAction.undo"): return "arrow.uturn.backward"
        case "重做操作", L.tr("logAction.redo"): return "arrow.uturn.forward"
        case "同步": return "icloud"
        default: return "circle"
        }
    }
}
