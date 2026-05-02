import SwiftUI

// MARK: - Index View (entry point with NavigationStack)
struct IndexView: View {
    var body: some View {
        IndexViewContent()
    }
}

// MARK: - Index View Content (for use inside parent NavigationStack)
struct IndexViewContent: View {
    @EnvironmentObject var store: KMStore

    var body: some View {
        List {
            // Summary
            Section {
                HStack(spacing: 10) {
                    IndexStatView(label: Localized.tr("index.pages"), value: "\(store.totalPages)", color: .wikiAccent)
                    IndexStatView(label: Localized.tr("index.entities"), value: "\(store.entityCount)", color: .wikiEntity)
                    IndexStatView(label: Localized.tr("index.concepts"), value: "\(store.conceptCount)", color: .wikiConcept)
                    IndexStatView(label: Localized.tr("index.sources"), value: "\(store.sourceCount)", color: .wikiSource)
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .listRowBackground(Color.clear)
            } header: {
                Text(Localized.tr("index.overview"))
            }

            // Entities
            let entities = store.pages.filter { $0.type == .entity }.sorted { $0.title < $1.title }
            if !entities.isEmpty {
                Section {
                    ForEach(entities) { page in
                        NavigationLink(destination: PageDetailView(page: page)) {
                            IndexRowView(page: page)
                        }
                    }
                } header: {
                    Label(Localized.trf("index.entityCount", entities.count), systemImage: "person.text.rectangle.fill")
                        .foregroundStyle(.wikiEntity)
                }
            }

            // Concepts
            let concepts = store.pages.filter { $0.type == .concept }.sorted { $0.title < $1.title }
            if !concepts.isEmpty {
                Section {
                    ForEach(concepts) { page in
                        NavigationLink(destination: PageDetailView(page: page)) {
                            IndexRowView(page: page)
                        }
                    }
                } header: {
                    Label(Localized.trf("index.conceptCount", concepts.count), systemImage: "lightbulb.fill")
                        .foregroundStyle(.wikiConcept)
                }
            }

            // Sources
            let sources = store.pages.filter { $0.type == .source }.sorted { $0.title < $1.title }
            if !sources.isEmpty {
                Section {
                    ForEach(sources) { page in
                        NavigationLink(destination: PageDetailView(page: page)) {
                            IndexRowView(page: page)
                        }
                    }
                } header: {
                    Label(Localized.trf("index.sourceCount", sources.count), systemImage: "doc.richtext.fill")
                        .foregroundStyle(.wikiSource)
                }
            }

            // Comparisons
            let comparisons = store.pages.filter { $0.type == .comparison }.sorted { $0.title < $1.title }
            if !comparisons.isEmpty {
                Section {
                    ForEach(comparisons) { page in
                        NavigationLink(destination: PageDetailView(page: page)) {
                            IndexRowView(page: page)
                        }
                    }
                } header: {
                    Label(Localized.trf("index.comparisonCount", comparisons.count), systemImage: "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(.wikiComparison)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("sidebar.masterIndex"))
    }
}

// MARK: - Index Stat View
struct IndexStatView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.wikiSecondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Index Row View
struct IndexRowView: View {
    let page: WikiPage
    @EnvironmentObject var store: KMStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: page.displayIcon)
                .foregroundStyle(page.type.themedColor)
                .frame(width: 28, height: 28)
                .background(page.type.themedColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(Localized.trf("index.wordCount", page.wordCount))
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)

                    if !page.tags.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                        Text(page.tags.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
            }

            Spacer()

            // Confidence indicator
            Circle()
                .fill(page.confidence.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}
