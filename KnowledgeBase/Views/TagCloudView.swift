import SwiftUI

struct TagCloudView: View {
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTag: String?
    @State private var tagToRename: String?
    @State private var newTagName = ""
    @State private var showDeleteConfirm = false
    @State private var tagToDelete: String?
    
    var tags: [(tag: String, count: Int)] {
        store.allTags
    }
    
    var filteredPages: [WikiPage] {
        guard let tag = selectedTag else { return store.pages }
        return store.pages.filter { $0.tags.contains(tag) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag cloud
                if tags.isEmpty {
                    // 无标签空状态
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 40))
                            .foregroundStyle(.wikiSecondary)
                        Text("还没有任何标签")
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text("在编辑页面时添加标签，或导入内容时指定标签")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.tag) { tagItem in
                                Button(action: {
                                    withAnimation {
                                        selectedTag = selectedTag == tagItem.tag ? nil : tagItem.tag
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text("#\(tagItem.tag)")
                                            .font(.subheadline.weight(selectedTag == tagItem.tag ? .bold : .regular))
                                        Text("\(tagItem.count)")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.wikiAccent.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTag == tagItem.tag ? Color.wikiAccent.opacity(0.2) : Color.wikiCard)
                                    .clipShape(Capsule())
                                    .foregroundStyle(selectedTag == tagItem.tag ? .wikiAccent : .wikiText)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(action: {
                                        tagToRename = tagItem.tag
                                        newTagName = tagItem.tag
                                    }) {
                                        Label("重命名", systemImage: "pencil")
                                    }
                                    Button(role: .destructive, action: {
                                        tagToDelete = tagItem.tag
                                        showDeleteConfirm = true
                                    }) {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Divider().background(Color.wikiBorder)
                
                // Pages with selected tag
                if let tag = selectedTag {
                    List {
                        Section {
                            ForEach(filteredPages.filter { $0.tags.contains(tag) }) { page in
                                NavigationLink(destination: PageDetailView(page: page)) {
                                    PageRowView(page: page, compact: true)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        } header: {
                            HStack {
                                Text("标签 #\(tag) 的页面")
                                    .foregroundStyle(.wikiText)
                                Spacer()
                                Text("\(filteredPages.filter { $0.tags.contains(tag) }.count) 个页面")
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tag")
                            .font(.title)
                            .foregroundStyle(.wikiSecondary)
                        Text("选择标签查看相关页面")
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .background(Color.wikiBackground)
            .navigationTitle("标签管理")
            .navigationBarTitleDisplayMode(.inline)
            .alert("重命名标签", isPresented: Binding(
                get: { tagToRename != nil },
                set: { if !$0 { tagToRename = nil } }
            )) {
                TextField("新名称", text: $newTagName)
                Button("取消", role: .cancel) { tagToRename = nil }
                Button("确定") {
                    guard let old = tagToRename, !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                    store.renameTag(old, to: trimmed)
                    if selectedTag == old { selectedTag = trimmed }
                    tagToRename = nil
                }
            } message: {
                Text("将 #\(tagToRename ?? "") 重命名为新名称")
            }
            .alert("删除标签", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) { tagToDelete = nil }
                Button("删除", role: .destructive) {
                    if let tag = tagToDelete {
                        store.deleteTag(tag)
                        if selectedTag == tag { selectedTag = nil }
                    }
                    tagToDelete = nil
                }
            } message: {
                let count = tags.first { $0.tag == tagToDelete }?.count ?? 0
                Text("将从 \(count) 个页面中移除 #\(tagToDelete ?? "")，此操作不可撤销")
            }
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}
