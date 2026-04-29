import SwiftUI

struct BacklinksView: View {
    let page: WikiPage
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    
    var backlinks: [WikiPage] {
        store.backlinks(for: page.id)
    }
    
    var outgoingPages: [WikiPage] {
        page.outgoingLinks.compactMap { store.pageByTitle($0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Outgoing links
                Section {
                    if outgoingPages.isEmpty {
                        Text(L.tr("backlinks.noOutgoing"))
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
                        Text(L.trf("backlinks.outgoingCount", outgoingPages.count))
                    }
                }
                
                // Backlinks
                Section {
                    if backlinks.isEmpty {
                        Text(L.tr("backlinks.noBackLinks"))
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
                        Text(L.trf("backlinks.backlinksCount", backlinks.count))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("backlinks.close")) { dismiss() }
                }
            }
        }
    }
}
