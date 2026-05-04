// WatchContentView.swift
//
// 作者: Wang Chong
// 功能说明: KMWatch 主界面 (Apple Watch)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// KMWatch 主界面 (Apple Watch)
/// 专注于极简查阅与快速采集。
struct WatchContentView: View {
    @Environment(KMStore.self) var store
    @State private var isShowingDictation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(L10n.Watch.tr("recents"))) {
                    ForEach(store.pages.sorted(by: { $0.updated > $1.updated }).prefix(5)) { page in
                        NavigationLink(value: page) {
                            HStack {
                                Image(systemName: page.displayIcon)
                                    .foregroundStyle(page.type.themedColor)
                                    .accessibilityHidden(true)
                                Text(page.title)
                                    .font(.caption.weight(.medium))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(page.title)
                        }
                    }
                }
                
                Section {
                    Button(action: { isShowingDictation = true }) {
                        Label(L10n.Watch.tr("capture"), systemImage: "mic.fill")
                            .foregroundStyle(.wikiAccent)
                    }
                }
            }
            .navigationTitle("智元")
            .navigationDestination(for: WikiPage.self) { page in
                WatchPageDetailView(page: page)
            }
            .sheet(isPresented: $isShowingDictation) {
                WatchDictationView()
            }
        }
    }
}

/// 手表端页面详情
struct WatchPageDetailView: View {
    let page: WikiPage
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(page.title)
                    .font(.headline)
                    .foregroundStyle(.wikiAccent)
                
                Divider()
                
                // 手表端仅显示摘要或精简内容
                Text(page.summary ?? page.content.prefix(200) + "...")
                    .font(.caption2)
            }
            .padding()
        }
    }
}
