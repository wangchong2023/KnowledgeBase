import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: KMStore
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
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.wikiSecondary)
                    TextField(Localized.tr("search.placeholder"), text: $searchText)
                        .foregroundStyle(.wikiText)
                        .accessibilityIdentifier("searchPlaceholder")

                    if !searchText.isEmpty {
                        Button(action: { 
                            searchText = ""
                            useAdvancedSearch = false
                            advancedResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.wikiSecondary)
                        }
                    }
                }
                .padding()
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                .padding(.horizontal)
                .padding(.top)

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Type filters
                        FilterPill(title: Localized.tr("search.all"), accessibilityIdentifier: "filter-all", isSelected: filterType == nil) {
                            HapticManager.selection()
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
                                HapticManager.selection()
                                filterType = type
                            }
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
                    .padding(.vertical, 10)
                }
                
                if store.llmService.isEnabled && !searchText.isEmpty {
                    Button(action: runAdvancedSearch) {
                        HStack {
                            if store.isAdvancedSearching {
                                ProgressView().scaleEffect(0.8).tint(.purple)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(useAdvancedSearch ? "显示全部结果" : "AI 深度语义搜索")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(useAdvancedSearch ? Color.purple.opacity(0.1) : Color.wikiAccent.opacity(0.1))
                        .foregroundStyle(useAdvancedSearch ? .purple : .wikiAccent)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                
                if useAdvancedSearch && store.lastSearchDiagnostic != nil {
                    Button(action: { showDiagnostics = true }) {
                        Label("查看检索诊断 (QA)", systemImage: "doc.text.magnifyingglass")
                            .font(.caption2)
                            .foregroundStyle(.purple.opacity(0.8))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Results
                if store.isAdvancedSearching {
                    VStack(spacing: 12) {
                        ForEach(0..<5) { _ in
                            HStack(spacing: 12) {
                                SkeletonBox(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 6) {
                                    SkeletonBox(width: 150, height: 16)
                                    SkeletonBox(width: 250, height: 12)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                } else if filteredPages.isEmpty {
                    VStack(spacing: 12) {
                        if searchText.isEmpty {
                            // 未搜索状态
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.wikiSecondary)
                            Text(Localized.tr("search.placeholder"))
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                        } else {
                            // 搜索无结果
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.wikiSecondary)
                            Text(Localized.tr("search.noResults"))
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                            Text(Localized.tr("search.noResultsHint"))
                                .font(.caption)
                                .foregroundStyle(.wikiSecondary.opacity(0.7))
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredPages) { page in
                            NavigationLink(value: page) {
                                PageRowView(page: page)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button {
                                    HapticManager.selection()
                                    previewPage = page
                                } label: {
                                    Label("快速预览", systemImage: "eye")
                                }
                                
                                Button {
                                    UIPasteboard.general.string = "[[\(page.title)]]"
                                } label: {
                                    Label("复制 WikiLink", systemImage: "link")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        // 本地数据无需刷新，仅提供视觉反馈
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    .navigationDestination(for: WikiPage.self) { destination in
                        PageDetailView(page: destination)
                    }
                }

                // Result count
                HStack {
                    Text(Localized.trf("search.pagesCount", filteredPages.count))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("search.title"))
            .sheet(item: $previewPage) { page in
                PagePreviewSheet(page: page)
            }
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
        
        HapticManager.selection()
        Task {
            let results = await store.performAdvancedSearch(query: store.searchText)
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
            .navigationTitle("预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
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
                Section("查询改写 (Rewrite)") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("原始查询", value: info.query)
                        LabeledContent("AI 改写结果", value: info.rewrittenQuery)
                            .foregroundStyle(.purple)
                    }
                    .font(.subheadline)
                }
                
                Section("RRF 融合排名详情 (Top 10)") {
                    ForEach(info.rrfTopResults) { res in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(res.title)
                                .font(.headline)
                            
                            HStack {
                                SearchBadgeView(label: "FTS 排名: \(res.ftsRank > 0 ? "\(res.ftsRank)" : "未命")", color: res.ftsRank > 0 ? .blue : .gray)
                                SearchBadgeView(label: "向量排名: \(res.vectorRank > 0 ? "\(res.vectorRank)" : "未命")", color: res.vectorRank > 0 ? .green : .gray)
                                Spacer()
                                Text(String(format: "得分: %.4f", res.finalScore))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.wikiSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("检索诊断报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
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
