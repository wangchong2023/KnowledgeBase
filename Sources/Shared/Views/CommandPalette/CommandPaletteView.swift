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
                Section("快速操作") {
                    CommandRow(icon: "sparkles", title: "AI 深度探索当前库", shortcut: "↵") {
                        // 触发逻辑
                        dismiss()
                    }
                    CommandRow(icon: "doc.badge.plus", title: "新建知识页面", shortcut: "N") {
                        dismiss()
                    }
                }
                
                Section("最近访问") {
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
