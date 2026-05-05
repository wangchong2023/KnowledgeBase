// IndexView.swift
//
// 作者: Wang Chong
// 功能说明: struct IndexView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Index View (entry point with NavigationStack)
struct IndexView: View {
    var filterType: PageType? = nil
    var body: some View {
        IndexViewContent(filterType: filterType)
    }
}

// MARK: - Index View Content (for use inside parent NavigationStack)
struct IndexViewContent: View {
    @Environment(KMStore.self) var store
    var filterType: PageType? = nil
    
    @State private var showDeleteConfirmation = false
    @State private var pageToDelete: WikiPage?

    var body: some View {
        List {
            if filterType == nil {
                // Summary
                Section {
                    HStack(spacing: 10) {
                        IndexStatView(label: L10n.Dashboard.tr("index.pages"), value: "\(store.totalPages)", color: .wikiAccent)
                        IndexStatView(label: L10n.Dashboard.tr("index.entities"), value: "\(store.entityCount)", color: .wikiEntity)
                        IndexStatView(label: L10n.Dashboard.tr("index.concepts"), value: "\(store.conceptCount)", color: .wikiConcept)
                        IndexStatView(label: L10n.Dashboard.tr("index.sources"), value: "\(store.sourceCount)", color: .wikiSource)
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .listRowBackground(Color.clear)
                } header: {
                    Text(L10n.Dashboard.tr("index.overview"))
                }
            }

            // Entities
            if filterType == nil || filterType == .entity {
                let entities = store.pages.filter { $0.type == .entity }.sorted { $0.title < $1.title }
                if !entities.isEmpty {
                    Section {
                        ForEach(entities) { page in
                            NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
                                IndexRowView(page: page)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pageToDelete = page
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(Localized.tr("page.deletePage"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Label(Localized.trf("index.entityCount", entities.count), systemImage: "person.text.rectangle.fill")
                            .foregroundStyle(.wikiEntity)
                    }
                }
            }

            // Concepts
            if filterType == nil || filterType == .concept {
                let concepts = store.pages.filter { $0.type == .concept }.sorted { $0.title < $1.title }
                if !concepts.isEmpty {
                    Section {
                        ForEach(concepts) { page in
                            NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
                                IndexRowView(page: page)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pageToDelete = page
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(Localized.tr("page.deletePage"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Label(Localized.trf("index.conceptCount", concepts.count), systemImage: "lightbulb.fill")
                            .foregroundStyle(.wikiConcept)
                    }
                }
            }

            // Sources
            if filterType == nil || filterType == .source {
                let sources = store.pages.filter { $0.type == .source }.sorted { $0.title < $1.title }
                if !sources.isEmpty {
                    Section {
                        ForEach(sources) { page in
                            NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
                                IndexRowView(page: page)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pageToDelete = page
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(Localized.tr("page.deletePage"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Label(Localized.trf("index.sourceCount", sources.count), systemImage: "doc.richtext.fill")
                            .foregroundStyle(.wikiSource)
                    }
                }
            }

            // Comparisons
            if filterType == nil || filterType == .comparison {
                let comparisons = store.pages.filter { $0.type == .comparison }.sorted { $0.title < $1.title }
                if !comparisons.isEmpty {
                    Section {
                        ForEach(comparisons) { page in
                            NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
                                IndexRowView(page: page)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pageToDelete = page
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(Localized.tr("page.deletePage"), systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Label(Localized.trf("index.comparisonCount", comparisons.count), systemImage: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.wikiComparison)
                    }
                }
            }
        }
        .confirmationDialog(
            pageToDelete.map { Localized.trf("page.deletePageTitle", $0.title) } ?? Localized.tr("page.deletePage"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(Localized.tr("page.deletePage"), role: .destructive) {
                if let page = pageToDelete {
                    store.deletePage(page)
                    HapticFeedback.shared.trigger(.success)
                }
            }
            Button(L10n.Common.tr("cancel"), role: .cancel) {
                pageToDelete = nil
            }
        } message: {
            Text(Localized.tr("settings.clearAll.message"))
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(filterType?.displayName ?? Localized.tr("sidebar.allPages"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticFeedback.shared.trigger(.selection)
                    store.refresh()
                } label: {
                    Label(L10n.Common.tr("refresh"), systemImage: "arrow.clockwise")
                }
            }
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
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.wikiSecondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
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
    @Environment(KMStore.self) var store

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
