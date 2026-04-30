import SwiftUI

struct CreatePageView: View {
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var type: PageType = .concept
    @State private var tags = ""
    @State private var content = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.tr("create.pageTitle"), text: $title)
                        .font(.body)
                        .accessibilityIdentifier("pageTitle")
                    
                    // Type picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PageType.allCases) { pageType in
                                Button(action: { type = pageType }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: pageType.icon)
                                            .font(.caption)
                                        Text(pageType.displayName)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(type == pageType ? pageType.themedColor.opacity(0.25) : Color.wikiCard)
                                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                                    .foregroundStyle(type == pageType ? pageType.themedColor : .wikiSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                                            .stroke(type == pageType ? pageType.themedColor.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    TextField(L.tr("create.tagsPlaceholder"), text: $tags)
                } header: {
                    Text(L.tr("create.basicInfo"))
                }
                
                Section {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                } header: {
                    HStack {
                        Text(L.tr("create.content"))
                        Spacer()
                        Text(L.tr("editor.bidirectionalLinks"))
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                
                // Quick templates
                Section {
                    Button(action: applyEntityTemplate) {
                        Label(L.tr("create.entityTemplate"), systemImage: "person.text.rectangle.fill")
                    }
                    Button(action: applyConceptTemplate) {
                        Label(L.tr("create.conceptTemplate"), systemImage: "lightbulb.fill")
                    }
                    Button(action: applyComparisonTemplate) {
                        Label(L.tr("create.comparisonTemplate"), systemImage: "arrow.left.arrow.right.circle.fill")
                    }
                } header: {
                    Text(L.tr("create.quickTemplates"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("create.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.tr("create.create")) {
                        createPage()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createPage() {
        let tagList = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let page = store.createPage(
            title: title,
            type: type,
            content: content,
            tags: tagList
        )
        
        store.selectedPageID = page.id
        dismiss()
    }
    
    private func applyEntityTemplate() {
        content = """
        # \(title)
        
        ## \(L.tr("create.overview"))
        
        ## \(L.tr("create.coreContributions"))
        
        ## \(L.tr("create.keyIdeas"))
        
        ## \(L.tr("create.relatedLinks"))
        
        """
    }
    
    private func applyConceptTemplate() {
        content = """
        # \(title)

        ## \(L.tr("create.definition"))

        ## \(L.tr("create.corePoints"))

        | \(L.tr("create.dimension")) | \(L.tr("create.description")) |
        |------|------|
        |  |  |

        ## \(L.tr("create.relatedLinks"))

        """
    }

    private func applyComparisonTemplate() {
        content = """
        # \(title)

        ## \(L.tr("create.comparisonDimensions"))

        | \(L.tr("create.dimension")) | A | B |
        |------|---|---|
        |  |  |  |

        ## \(L.tr("create.conclusion"))

        ## \(L.tr("create.relatedLinks"))

        """
    }
}
