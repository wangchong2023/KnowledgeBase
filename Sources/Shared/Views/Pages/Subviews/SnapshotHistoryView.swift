import SwiftUI

// MARK: - Snapshot History View
struct SnapshotHistoryView: View {
    let page: WikiPage
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var history: [SnapshotInfo] = []
    @State private var selectedSnapshot: SnapshotInfo?
    @State private var compareContent: String?

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    Text(Localized.tr("page.history.none"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { snapshot in
                        Button(action: {
                            selectedSnapshot = snapshot
                            compareContent = store.snapshotService.rollback(to: snapshot)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.medium))
                                    Text(Localized.tr("page.history.physical"))
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.wikiBorder)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(Localized.tr("page.history"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.close")) { dismiss() }
                }
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                SnapshotDetailView(page: page, snapshot: snapshot, content: compareContent ?? "", onRollback: {
                    var rolledBack = page
                    rolledBack.content = compareContent ?? ""
                    store.updatePage(rolledBack, forceDeepScan: false)
                    dismiss()
                })
            }
        }
        .onAppear {
            history = store.snapshotService.getHistory(for: page.id)
        }
    }
}

private struct SnapshotDetailView: View {
    let page: WikiPage
    let snapshot: SnapshotInfo
    let content: String
    let onRollback: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label(Localized.tr("page.history.version"), systemImage: "clock")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.wikiAccent)
                            Spacer()
                            Text(snapshot.date.formatted())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)

                        MarkdownRendererView(content: content, isPrivate: page.isPrivate, onLinkTap: { _ in })
                    }
                    .padding()
                }

                Divider()

                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text(Localized.tr("misc.cancel"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.wikiCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button(action: onRollback) {
                        Text(Localized.tr("page.history.rollback"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.wikiAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle(Localized.tr("page.snapshot.preview"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background(Color.wikiBackground)
        }
    }
}
