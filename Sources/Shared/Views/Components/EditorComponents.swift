// EditorComponents.swift
//
// 作者: Wang Chong
// 功能说明: struct WikilinkPickerSheet
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Wikilink Picker Sheet
/// WikiLink 选择器面板组件
/// 负责在编辑器中搜索并插入双链引用的选择界面，支持模糊搜索及页面类型过滤
struct WikilinkPickerSheet: View {
    @Binding var page: WikiPage
    @Binding var editorContent: String
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredPages: [WikiPage] {
        let pages = store.pages.filter { $0.id != page.id }
        if searchText.isEmpty { return pages }
        return pages.filter { $0.title.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                pageList
            }
            .background(Color.wikiBackground)
            .navigationTitle(L10n.Editor.tr("insertWikiLink"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.wikiSecondary)
            TextField(L10n.Editor.tr("searchPages"), text: $searchText)
                .foregroundStyle(.wikiText)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .padding()
        .background(Color.wikiCard)
    }
    
    private var pageList: some View {
        List {
            ForEach(filteredPages) { p in
                Button(action: {
                    editorContent += " [[\(p.title)]]"
                    dismiss()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: p.type.icon)
                            .foregroundStyle(p.type.themedColor)
                            .frame(width: 28, height: 28)
                            .background(p.type.themedColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title)
                                .font(.subheadline)
                                .foregroundStyle(.wikiText)
                            Text(p.type.displayName)
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.wikiText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Editor Toolbar Button
/// 编辑器工具栏按钮组件
/// 负责展示编辑器底部的辅助操作按钮（如插入加粗、链接等），采用一致的紧凑型布局
struct EditorToolbarButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 9))
            }
            .foregroundStyle(.wikiSecondary)
            .frame(width: 44, height: 36)
            .background(Color.wikiBorder.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}

// MARK: - Tag Chip
/// 可删除的标签胶囊。
/// 标签胶囊组件
/// 负责在编辑器顶部展示已添加的标签，支持单个标签的快速移除与高亮样式
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
                .foregroundStyle(.wikiAccent)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.wikiAccent.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Alias Chip
/// 可删除的别名胶囊。
/// 别名胶囊组件
/// 负责在编辑器中展示页面的别名信息，提供视觉区分度及移除交互
struct AliasChip: View {
    let alias: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(alias)
                .font(.caption)
                .foregroundStyle(.wikiSource)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.wikiSource.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Inline Tag Input
/// 内联标签输入框。
/// 内联标签输入组件
/// 负责在编辑器内提供非阻塞式的标签添加输入框，支持回车确认与取消操作
struct InlineTagInput: View {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField(L10n.Editor.tr("enterTag"), text: $text)
                .font(.caption)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                .foregroundStyle(.wikiText)
                .onSubmit { onCommit() }
            
            Button(action: onCommit) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.wikiBackground)
    }
}