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
        .navigationTitle(Localized.tr("settings.operationLog"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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
                        Text(Localized.tr(entry.action))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(actionColor(entry.action))
                        Text("·")
                            .foregroundStyle(.wikiSecondary)
                        Text(entry.target)
                            .font(.caption)
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
                    Text(Localized.tr("log.noDetails"))
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
        case "创建", Localized.tr("logAction.create"): return .green
        case "更新", Localized.tr("logAction.update"): return .blue
        case "删除", Localized.tr("logAction.delete"): return .red
        case "Lint", Localized.tr("logAction.lint"), Localized.tr("logAction.healthCheck"): return .orange
        case "导入", Localized.tr("logAction.ingest"): return .wikiSource
        case "智能导入", Localized.tr("logAction.smartIngest"): return .wikiAccent
        case "撤销操作", Localized.tr("logAction.undo"): return .purple
        case "重做操作", Localized.tr("logAction.redo"): return .purple
        case "同步", Localized.tr("logAction.sync"): return .teal
        case "导入PDF", Localized.tr("logAction.importPDF"), Localized.tr("logAction.ingestPDF"): return .wikiSource
        case "删除PDF", Localized.tr("logAction.deletePDF"): return .red
        case "高亮标注", Localized.tr("logAction.highlight"): return .wikiAccent
        case "OCR识别", Localized.tr("logAction.ocrRecognize"): return .wikiConcept
        default: return .wikiSecondary
        }
    }

    private func actionIcon(_ action: String) -> String {
        switch action {
        case "创建", Localized.tr("logAction.create"): return "plus"
        case "更新", Localized.tr("logAction.update"): return "pencil"
        case "删除", Localized.tr("logAction.delete"): return "trash"
        case "Lint", Localized.tr("logAction.lint"), Localized.tr("logAction.healthCheck"): return "stethoscope"
        case "导入", Localized.tr("logAction.ingest"): return "arrow.down.doc"
        case "智能导入", Localized.tr("logAction.smartIngest"): return "sparkles"
        case "撤销操作", Localized.tr("logAction.undo"): return "arrow.uturn.backward"
        case "重做操作", Localized.tr("logAction.redo"): return "arrow.uturn.forward"
        case "同步", Localized.tr("logAction.sync"): return "icloud"
        case "导入PDF", Localized.tr("logAction.importPDF"), Localized.tr("logAction.ingestPDF"): return "arrow.down.doc"
        case "删除PDF", Localized.tr("logAction.deletePDF"): return "trash"
        case "高亮标注", Localized.tr("logAction.highlight"): return "highlighter"
        case "OCR识别", Localized.tr("logAction.ocrRecognize"): return "text.viewfinder"
        default: return "circle"
        }
    }
}
