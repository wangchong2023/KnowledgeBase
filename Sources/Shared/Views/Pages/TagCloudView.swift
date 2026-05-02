import SwiftUI

struct TagCloudView: View {
    @Environment(KMStore.self) var store
    @State private var tags: [(tag: String, count: Int)] = []
    @State private var isLoading = false
    @State private var searchText = ""
    
    @State private var showRenameSheet = false
    @State private var tagToRename = ""
    @State private var newTagName = ""
    
    @State private var showDeleteAlert = false
    @State private var tagToDelete = ""

    var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.tag.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        TagCloudFlowSection(
                            tags: filteredTags,
                            onRename: { tag in
                                tagToRename = tag
                                newTagName = tag
                                showRenameSheet = true
                            },
                            onDelete: { tag in
                                tagToDelete = tag
                                showDeleteAlert = true
                            }
                        )
                    }
                }
            }
            .navigationTitle(Localized.tr("tagCloud.title"))
            .searchable(text: $searchText, prompt: Localized.tr("tagCloud.searchPrompt"))
            .task {
                isLoading = true
                tags = await store.getAllTags()
                isLoading = false
            }
            .sheet(isPresented: $showRenameSheet) {
                renameSheet
            }
            .alert(Localized.tr("tagCloud.deleteConfirm"), isPresented: $showDeleteAlert) {
                Button(Localized.tr("tagCloud.delete"), role: .destructive) {
                    store.deleteTag(tagToDelete)
                    Task { tags = await store.getAllTags() }
                }
                Button(Localized.tr("misc.cancel"), role: .cancel) {}
            } message: {
                Text(Localized.trf("tagCloud.deleteDesc", tagToDelete))
            }
        }
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField(Localized.tr("tagCloud.newName"), text: $newTagName)
            }
            .navigationTitle(Localized.tr("tagCloud.rename"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localized.tr("misc.cancel")) { showRenameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Localized.tr("misc.save")) {
                        store.renameTag(tagToRename, to: newTagName)
                        showRenameSheet = false
                        Task { tags = await store.getAllTags() }
                    }
                    .disabled(newTagName.isEmpty || newTagName == tagToRename)
                }
            }
        }
    }
}

struct TagCloudFlowSection: View {
    let tags: [(tag: String, count: Int)]
    var onRename: (String) -> Void
    var onDelete: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 12) {
            ForEach(tags, id: \.tag) { item in
                TagCapsule(tag: item.tag, count: item.count)
                    .contextMenu {
                        Button { onRename(item.tag) } label: {
                            Label(Localized.tr("tagCloud.rename"), systemImage: "pencil")
                        }
                        Button(role: .destructive) { onDelete(item.tag) } label: {
                            Label(Localized.tr("tagCloud.delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .padding()
    }
}
