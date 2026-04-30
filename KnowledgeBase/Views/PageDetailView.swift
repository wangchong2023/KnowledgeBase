import SwiftUI

struct PageDetailView: View {
    @State var page: WikiPage
    @EnvironmentObject var store: KMStore
    @State private var isEditing = false
    @State private var showBacklinks = false
    @State private var showDeleteConfirmation = false
    @State private var showAliasEditor = false
    @State private var newAlias = ""
    @State private var showIconPicker = false
    
    var backlinks: [WikiPage] {
        store.backlinks(for: page.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageDetailHeader(page: page)
                
                Divider()
                    .background(Color.wikiBorder)
                
                // Content
                if isEditing {
                    MarkdownEditorView(page: $page, isEditing: $isEditing)
                } else if page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 空内容占位提示
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 32))
                            .foregroundStyle(.wikiSecondary)
                        Text(L.tr("page.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                        Text(L.tr("page.emptyHint"))
                            .font(.caption)
                            .foregroundStyle(.wikiAccent.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.wikiAccent.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                } else {
                    MarkdownRendererView(content: page.content, onLinkTap: { title in
                        navigateToPage(title)
                    })
                    .padding()
                }
                
                Divider()
                    .background(Color.wikiBorder)
                    .padding(.horizontal)
                
                // Backlinks section
                backlinksSection
            }
        }
        .background(Color.wikiBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Register navigationDestination so NavigationLink(value: WikiPage) works
        // both in the Graph tab's NavigationStack and elsewhere.
        .navigationDestination(for: WikiPage.self) { destination in
            PageDetailView(page: destination)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Pin/Unpin button
                Button(action: {
                    page.isPinned.toggle()
                    store.updatePage(page)
                }) {
                    Image(systemName: page.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(page.isPinned ? .wikiComparison : .wikiSecondary)
                }
                .accessibilityLabel(page.isPinned ? L.tr("page.unpin") : L.tr("page.pin"))
                
                Button(action: { showBacklinks.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("\(backlinks.count)")
                    }
                    .foregroundStyle(.wikiAccent)
                }
                .accessibilityLabel(L.tr("page.backlinks"))
                .accessibilityValue(L.trf("page.backlinksCount", backlinks.count))

                Button(action: {
                    if isEditing {
                        store.updatePage(page)
                    }
                    isEditing.toggle()
                }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .foregroundStyle(isEditing ? .green : .wikiAccent)
                }
                .accessibilityLabel(isEditing ? L.tr("page.doneEditing") : L.tr("page.edit"))
            }
            
            ToolbarItemGroup(placement: .topBarLeading) {
                Menu {
                    // Page type
                    Menu {
                        ForEach(PageType.allCases) { type in
                            Button(action: {
                                page.type = type
                                store.updatePage(page)
                            }) {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    } label: {
                        Label(L.tr("page.type"), systemImage: page.displayIcon)
                    }

                    // Page icon
                    Button(action: { showIconPicker = true }) {
                        HStack {
                            Image(systemName: page.displayIcon)
                            Text(L.tr("page.icon"))
                            if page.customIcon != nil {
                                Spacer()
                                Text(L.tr("editor.iconCustomized"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Page status
                    Menu {
                        ForEach(PageStatus.allCases, id: \.self) { status in
                            Button(action: {
                                page.status = status
                                store.updatePage(page)
                            }) {
                                Label(status.displayName, systemImage: "circle.fill")
                                    .foregroundStyle(status.color)
                            }
                        }
                    } label: {
                        Label(L.trf("page.statusFormat", page.status.displayName), systemImage: "flag.fill")
                    }
                    
                    // Confidence
                    Menu {
                        ForEach(Confidence.allCases, id: \.self) { conf in
                            Button(action: {
                                page.confidence = conf
                                store.updatePage(page)
                            }) {
                                Label(conf.displayName, systemImage: "signal")
                            }
                        }
                    } label: {
                        Label(L.trf("page.confidenceFormat", page.confidence.displayName), systemImage: "signal")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label(L.tr("page.deletePage"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .confirmationDialog(L.tr("page.confirmDelete"), isPresented: $showDeleteConfirmation) {
            Button(L.trf("page.deletePageTitle", page.title), role: .destructive) {
                store.deletePage(page)
            }
            Button(L.tr("misc.cancel"), role: .cancel) {}
        } message: {
            Text(L.tr("page.deleteMessage"))
        }
        .sheet(isPresented: $showBacklinks) {
            BacklinksView(page: page)
        }
        .sheet(isPresented: $showIconPicker) {
            NavigationStack {
                IconPickerView(selectedIcon: Binding(
                    get: { page.customIcon },
                    set: { newIcon in
                        page.customIcon = newIcon
                        store.updatePage(page)
                    }
                ))
            }
        }
        .onChange(of: page) { _, newValue in
            if !isEditing {
                store.updatePage(newValue)
            }
        }
    }
    
    // MARK: - Backlinks Section
    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.wikiAccent)
                Text(L.tr("page.backlinks"))
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Text("(\(backlinks.count))")
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
            }
            
            if backlinks.isEmpty {
                Text(L.tr("page.noBackLinks"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(backlinks) { linkedPage in
                    NavigationLink(value: linkedPage) {
                        HStack(spacing: 10) {
                            Image(systemName: linkedPage.displayIcon)
                                .foregroundStyle(linkedPage.type.themedColor)
                                .frame(width: 28, height: 28)
                                .background(linkedPage.type.themedColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))

                            Text(linkedPage.title)
                                .font(.subheadline)
                                .foregroundStyle(.wikiText)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.wikiCard)
                        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.trf("page.backlinkAccessibility", linkedPage.title, linkedPage.type.displayName))
                    .accessibilityHint(L.tr("page.doubleTapToNavigate"))
                }
            }
        }
        .padding()
    }
    
    // MARK: - Navigation
    private func navigateToPage(_ title: String) {
        if let target = store.pageByTitle(title) {
            store.selectedPageID = target.id
        }
    }
}
