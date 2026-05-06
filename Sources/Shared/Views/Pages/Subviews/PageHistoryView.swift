// PageHistoryView.swift
//
// 作者: Wang Chong
// 功能说明: 页面历史快照列表面板 (Refactored from PageDetailView)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

/// 页面历史快照列表面板 (Refactored from PageDetailView)
struct PageHistoryView: View {
    let page: WikiPage
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var history: [SnapshotInfo] = []
    @State private var selectedSnapshot: SnapshotInfo? = nil
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(history) { snapshot in
                    Button(action: { selectedSnapshot = snapshot }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Localized.tr("page.history.manual"))
                                    .font(.subheadline.weight(.medium))
                                Text(snapshot.date.formatted())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
            .navigationTitle(Localized.tr("page.history"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("close")) { dismiss() }
                }
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                SnapshotDetailView(page: page, snapshot: snapshot, store: store)
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
    let store: KMStore
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
                        
                        Divider()
                        
                        // 简化展示历史内容（实际应支持 Diff）
                        Text(page.content) // 占位
                            .font(.callout)
                    }
                    .padding()
                }
                
                Button(action: {
                    // 执行回滚逻辑
                    dismiss()
                }) {
                    Label(Localized.tr("page.history.rollback"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.wikiAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
