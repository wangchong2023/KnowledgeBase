// CommandPaletteView.swift
//
// 作者: Wang Chong
// 功能说明: 全局指令中枢 (Command Palette)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 全局指令中枢 (Command Palette)
/// 满足硬核用户 Cmd+K 盲操需求，极大缩短交互路径。
struct CommandPaletteView: View {
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "command")
                    .foregroundStyle(.wikiAccent)
                TextField(Localized.tr("palette.searchPlaceholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                Text("ESC")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .background(Color.wikiBorder.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding()
            .background(Color.wikiCard)
            
            Divider()
            
            // 结果列表
            List {
                Section(L10n.Action.tr("cmd.quickActions")) {
                    CommandRow(icon: "sparkles", title: L10n.Action.tr("cmd.deepExplore"), shortcut: "↵") {
                        // 触发逻辑
                        dismiss()
                    }
                    CommandRow(icon: "doc.badge.plus", title: L10n.Action.tr("cmd.newWikiPage"), shortcut: "N") {
                        dismiss()
                    }
                }
                
                Section(L10n.Action.tr("cmd.recentAccess")) {
                    ForEach(store.pages.prefix(3)) { page in
                        CommandRow(icon: page.type.icon, title: page.title) {
                            dismiss()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: 300)
        }
        .background(Color.wikiBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .frame(width: 500)
        .onAppear { isFocused = true }
    }
}

private struct CommandRow: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                Spacer()
                if let sc = shortcut {
                    Text(sc)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
    }
}
