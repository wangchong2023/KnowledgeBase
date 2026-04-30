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
                        Text(Localized.tr("tag.noTags"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text(Localized.tr("tag.noTagsHint"))
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
                                        Label(Localized.tr("tag.rename"), systemImage: "pencil")
                                    }
                                    Button(role: .destructive, action: {
                                        tagToDelete = tagItem.tag
                                        showDeleteConfirm = true
                                    }) {
                                        Label(Localized.tr("tag.delete"), systemImage: "trash")
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
                                Text(Localized.trf("tag.tagPages", tag))
                                    .foregroundStyle(.wikiText)
                                Spacer()
                                Text(Localized.trf("page.backlinksCount", filteredPages.filter { $0.tags.contains(tag) }.count))
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
                        Text(Localized.tr("tagcloud.selectTag"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("tag.title"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(Localized.tr("tag.renameTag"), isPresented: Binding(
                get: { tagToRename != nil },
                set: { if !$0 { tagToRename = nil } }
            )) {
                TextField(Localized.tr("tag.newName"), text: $newTagName)
                Button(Localized.tr("misc.cancel"), role: .cancel) { tagToRename = nil }
                Button(Localized.tr("misc.ok")) {
                    guard let old = tagToRename, !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                    store.renameTag(old, to: trimmed)
                    if selectedTag == old { selectedTag = trimmed }
                    tagToRename = nil
                }
            } message: {
                Text(Localized.trf("tag.renameMessage", tagToRename ?? ""))
            }
            .alert(Localized.tr("tag.deleteTag"), isPresented: $showDeleteConfirm) {
                Button(Localized.tr("misc.cancel"), role: .cancel) { tagToDelete = nil }
                Button(Localized.tr("misc.delete"), role: .destructive) {
                    if let tag = tagToDelete {
                        store.deleteTag(tag)
                        if selectedTag == tag { selectedTag = nil }
                    }
                    tagToDelete = nil
                }
            } message: {
                let count = tags.first { $0.tag == tagToDelete }?.count ?? 0
                Text(Localized.trf("tag.deleteMessage", count, tagToDelete ?? ""))
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
