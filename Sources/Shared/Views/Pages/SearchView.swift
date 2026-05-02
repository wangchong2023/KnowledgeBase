import SwiftUI

struct SearchView: View {
    @Environment(KMStore.self) var store
    @Environment(\.navigate) var navigate
    @State private var searchText = ""
    @State private var filterType: PageType?
    @State private var filterStatus: PageStatus?
    @State private var sortBy: SortOption = .updated
    @State private var previewPage: WikiPage?
    @State private var advancedResults: [WikiPage] = []
    @State private var useAdvancedSearch = false
    @State private var showDiagnostics = false
    
    enum SortOption: String, CaseIterable {
        case updated = "search.sort.recentlyUpdated"
        case created = "search.sort.recentlyCreated"
        case title = "search.sort.title"
        case type = "search.sort.type"
    }
    
    var filteredPages: [WikiPage] {
        if useAdvancedSearch && !advancedResults.isEmpty {
            return advancedResults
        }
        
        var result = store.pages
        
        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { page in
                page.title.lowercased().contains(query) ||
                page.content.lowercased().contains(query) ||
                page.tags.contains(where: { $0.lowercased().contains(query) }) ||
                page.aliases.contains(where: { $0.lowercased().contains(query) })
            }
        }
        
        // Type filter
        if let type = filterType {
            result = result.filter { $0.type == type }
        }
        
        // Status filter
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        
        // Sort
        switch sortBy {
        case .updated:
            result.sort { $0.updated > $1.updated }
        case .created:
            result.sort { $0.created > $1.created }
        case .title:
            result.sort { $0.title < $1.title }
        case .type:
            result.sort { $0.type.rawValue < $1.type.rawValue }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header (Bar + Filters)
            VStack(spacing: 12) {
                // Unified Search Bar
                HStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.wikiSecondary)
                        TextField(Localized.tr("search.placeholder"), text: $searchText)
                            .foregroundStyle(.wikiText)
                            .accessibilityIdentifier("searchPlaceholder")
                            .submitLabel(.search)
                            .onSubmit {
                                if !searchText.isEmpty {
                                    runAdvancedSearch()
                                }
                            }

                        if !searchText.isEmpty {
                            Button(action: { 
                                searchText = ""
                                useAdvancedSearch = false
                                advancedResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.wikiSecondary)
                            }
                            .padding(.trailing, 4)
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.vertical, 10)
                    .background(Color.wikiCard)
                }
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 0.5)
                )
                .padding(.horizontal)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: searchText.isEmpty)
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: Localized.tr("search.all"), accessibilityIdentifier: "filter-all", isSelected: filterType == nil) {
                            HapticManager.shared.trigger(.selection)
                            filterType = nil
                        }

                        ForEach(PageType.allCases) { type in
                            FilterPill(
                                title: type.displayName,
                                icon: type.icon,
                                color: type.themedColor,
                                accessibilityIdentifier: "filter-\(type.rawValue)",
                                isSelected: filterType == type
                            ) {
                                HapticManager.shared.trigger(.selection)
                                filterType = type
                            }
                        }

                        Divider().frame(height: 24).background(Color.wikiBorder)

                        // Status Filters
                        Menu {
                            Button(Localized.tr("misc.all")) { filterStatus = nil }
                            ForEach(PageStatus.allCases, id: \.self) { status in
                                Button(status.displayName) { filterStatus = status }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flag")
                                    .font(.caption)
                                Text(filterStatus?.displayName ?? Localized.tr("page.status"))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(filterStatus == nil ? Color.wikiCard : Color.wikiAccent.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(filterStatus == nil ? .wikiSecondary : .wikiAccent)
                        }

                        Divider().frame(height: 24).background(Color.wikiBorder)

                        // Sort options
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortBy = option }) {
                                    Label(Localized.tr(option.rawValue), systemImage: sortBy == option ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.caption)
                                Text(Localized.tr(sortBy.rawValue))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.wikiCard)
                            .clipShape(Capsule())
                            .foregroundStyle(.wikiSecondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 12)
            .background(Color.wikiBackground)
            
            
            // Main Results Content
            ZStack {
                if store.isAdvancedSearching {
                    VStack(spacing: 16) {
                        ForEach(0..<6) { _ in
                            HStack(spacing: 12) {
                                SkeletonBox(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonBox(width: 140, height: 14)
                                    SkeletonBox(width: 240, height: 10)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if filteredPages.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? "magnifyingglass" : "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.wikiSecondary.opacity(0.5))
                        
                        Text(searchText.isEmpty ? Localized.tr("search.placeholder") : Localized.tr("search.noResults"))
                            .font(.headline)
                            .foregroundStyle(.wikiSecondary)
                        
                        if !searchText.isEmpty {
                            Text(Localized.tr("search.noResultsHint"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredPages) { page in
                            Button(action: {
                                HapticManager.shared.trigger(.selection)
                                navigate(page)
                            }) {
                                PageRowView(page: page)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button {
                                    HapticManager.shared.trigger(.selection)
                                    previewPage = page
                                } label: {
                                    Label(Localized.tr("misc.quickPreview"), systemImage: "eye")
                                }
                                
                                Button {
                                    WikiPasteboard.string = "[[\(page.title)]]"
                                } label: {
                                    Label(Localized.tr("misc.copyWikiLink"), systemImage: "link")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .animation(.default, value: store.isAdvancedSearching)
            .animation(.default, value: filteredPages.isEmpty)
            
            // Footer
            if !filteredPages.isEmpty {
                Divider().background(Color.wikiBorder.opacity(0.5))
                HStack {
                    Text(Localized.trf("search.pagesCount", filteredPages.count))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                    
                    if useAdvancedSearch {
                        Spacer()
                        Button(action: { showDiagnostics = true }) {
                            Label(Localized.tr("search.diagnostics"), systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundStyle(.wikiAccent)
                        }
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.wikiBackground)
            }
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("search.title"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .sheet(item: $previewPage) { page in
            PagePreviewSheet(page: page)
        }
        .sheet(isPresented: $showDiagnostics) {
            if let diag = store.lastSearchDiagnostic {
                SearchDiagnosticSheet(info: diag)
            }
        }
    }
    
    private func runAdvancedSearch() {
        if useAdvancedSearch {
            withAnimation {
                useAdvancedSearch = false
                advancedResults = []
            }
            return
        }
        
        HapticManager.shared.trigger(.selection)
        Task {
            let results = await store.performAdvancedSearch(query: searchText)
            await MainActor.run {
                withAnimation {
                    self.advancedResults = results
                    self.useAdvancedSearch = true
                }
            }
        }
    }
}

// MARK: - Quick Preview Sheet
struct PagePreviewSheet: View {
    let page: WikiPage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        WikiIconChip(icon: page.type.icon, text: page.type.displayName, color: page.type.themedColor, isSelected: true)
                        Spacer()
                        Text(page.updated, style: .date)
                            .font(.caption)
                            .foregroundStyle(.wikiSecondary)
                    }
                    
                    Text(page.title)
                        .font(.title2.bold())
                        .foregroundStyle(.wikiText)
                    
                    Divider()
                    
                    Text(page.content)
                        .font(.subheadline)
                        .foregroundStyle(.wikiText)
                        .lineLimit(20)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("misc.preview"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    var icon: String? = nil
    var color: Color = .wikiAccent
    var accessibilityIdentifier: String? = nil
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 大屏幕下使用 subheadline 字体（约 15pt），小屏幕用 caption（约 12pt）
    private var pillFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(pillFont.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.25) : Color.wikiCard)
            .clipShape(Capsule())
            .foregroundStyle(isSelected ? color : .wikiSecondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

// MARK: - Search Diagnostic Sheet
struct SearchDiagnosticSheet: View {
    let info: SearchDiagnosticInfo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(Localized.tr("search.diag.rewrite")) {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(Localized.tr("search.diag.originalQuery"), value: info.query)
                        LabeledContent(Localized.tr("search.diag.rewrittenQuery"), value: info.rewrittenQuery)
                            .foregroundStyle(.purple)
                    }
                    .font(.subheadline)
                }
                
                Section(Localized.tr("search.diag.rrfDetail")) {
                    ForEach(info.rrfTopResults) { res in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(res.title)
                                .font(.headline)
                            
                            HStack {
                                SearchBadgeView(label: "\(Localized.tr("search.diag.ftsRank")): \(res.ftsRank > 0 ? "\(res.ftsRank)" : Localized.tr("search.diag.miss"))", color: res.ftsRank > 0 ? .blue : .gray)
                                SearchBadgeView(label: "\(Localized.tr("search.diag.vectorRank")): \(res.vectorRank > 0 ? "\(res.vectorRank)" : Localized.tr("search.diag.miss"))", color: res.vectorRank > 0 ? .green : .gray)
                                Spacer()
                                Text(String(format: Localized.tr("search.diag.scoreFormat"), res.finalScore))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.wikiSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(Localized.tr("search.diag.title"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("misc.close")) { dismiss() }
                }
            }
        }
    }
}

struct SearchBadgeView: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
