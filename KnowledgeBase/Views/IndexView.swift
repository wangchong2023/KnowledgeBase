import SwiftUI

struct IndexView: View {
    @EnvironmentObject var store: KMStore
    
    var body: some View {
        NavigationStack {
            List {
                // Summary
                Section {
                    HStack {
                        IndexStatView(label: "页面", value: "\(store.totalPages)", color: .wikiAccent)
                        IndexStatView(label: "实体", value: "\(store.entityCount)", color: .wikiEntity)
                        IndexStatView(label: "概念", value: "\(store.conceptCount)", color: .wikiConcept)
                        IndexStatView(label: "来源", value: "\(store.sourceCount)", color: .wikiSource)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("概览")
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
                        Label("实体 (\(entities.count))", systemImage: "person.text.rectangle.fill")
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
                        Label("概念 (\(concepts.count))", systemImage: "lightbulb.fill")
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
                        Label("来源 (\(sources.count))", systemImage: "doc.richtext.fill")
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
                        Label("对比 (\(comparisons.count))", systemImage: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.wikiComparison)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle("总索引")
        }
    }
}

// MARK: - Index Stat View
struct IndexStatView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity)
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
                    Text("\(page.wordCount) 字")
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
