import SwiftUI

struct BacklinksView: View {
    let page: WikiPage
    @Environment(KMStore.self) var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var backlinks: [WikiPage] = []
    @State private var outgoingPages: [WikiPage] = []
    @State private var isLoading = true
    
    private func fetchData() async {
        isLoading = true
        let bl = store.getBacklinks(for: page.id)
        
        var op: [WikiPage] = []
        for title in page.outgoingLinks {
            if let p = await store.pageByTitle(title) {
                op.append(p)
            }
        }
        
        await MainActor.run {
            self.backlinks = bl
            self.outgoingPages = op
            self.isLoading = false
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Outgoing links
                Section {
                    if outgoingPages.isEmpty {
                        Text(Localized.tr("backlinks.noOutgoing"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    } else {
                        ForEach(outgoingPages) { linkedPage in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.wikiAccent)
                                
                                Image(systemName: linkedPage.displayIcon)
                                    .foregroundStyle(linkedPage.type.themedColor)
                                    .frame(width: 28, height: 28)
                                    .background(linkedPage.type.themedColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(linkedPage.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.wikiText)
                                    Text(linkedPage.type.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "arrow.right")
                        Text(Localized.trf("backlinks.outgoingCount", outgoingPages.count))
                    }
                }
                
                // Backlinks
                Section {
                    if backlinks.isEmpty {
                        Text(Localized.tr("backlinks.noBackLinks"))
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    } else {
                        ForEach(backlinks) { linkingPage in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.left")
                                    .font(.caption)
                                    .foregroundStyle(.wikiComparison)
                                
                                Image(systemName: linkingPage.displayIcon)
                                    .foregroundStyle(linkingPage.type.themedColor)
                                    .frame(width: 28, height: 28)
                                    .background(linkingPage.type.themedColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(linkingPage.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.wikiText)
                                    Text(linkingPage.type.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.wikiSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text(Localized.trf("backlinks.backlinksCount", backlinks.count))
                    }
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(page.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .task {
                await fetchData()
            }
        }
    }
}
