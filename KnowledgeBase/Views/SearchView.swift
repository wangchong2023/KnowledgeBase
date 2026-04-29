import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: KMStore
    @State private var searchText = ""
    @State private var filterType: PageType?
    @State private var filterStatus: PageStatus?
    @State private var sortBy: SortOption = .updated
    
    enum SortOption: String, CaseIterable {
        case updated = "最近更新"
        case created = "最近创建"
        case title = "标题"
        case type = "类型"
    }
    
    var filteredPages: [WikiPage] {
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
                    TextField("搜索页面、标签、内容...", text: $searchText)
                        .foregroundStyle(.wikiText)
                        .accessibilityIdentifier("搜索页面、标签、内容...")
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
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
                        FilterPill(title: "全部", isSelected: filterType == nil) {
                            filterType = nil
                        }
                        
                        ForEach(PageType.allCases) { type in
                            FilterPill(
                                title: type.displayName,
                                icon: type.icon,
                                color: type.themedColor,
                                isSelected: filterType == type
                            ) {
                                filterType = type
                            }
                        }
                        
                        Divider().frame(height: 24).background(Color.wikiBorder)
                        
                        // Sort options
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortBy = option }) {
                                    Label(option.rawValue, systemImage: sortBy == option ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.caption)
                                Text(sortBy.rawValue)
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
                
                // Results
                if filteredPages.isEmpty {
                    VStack(spacing: 12) {
                        if searchText.isEmpty {
                            // 未搜索状态
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.wikiSecondary)
                            Text("输入关键词搜索页面、标签或内容")
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                        } else {
                            // 搜索无结果
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.wikiSecondary)
                            Text("没有找到匹配的页面")
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                            Text("尝试更换关键词或调整筛选条件")
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
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .navigationDestination(for: WikiPage.self) { destination in
                        PageDetailView(page: destination)
                    }
                }
                
                // Result count
                HStack {
                    Text("\(filteredPages.count) 个页面")
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color.wikiBackground)
            .navigationTitle("搜索")
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    var icon: String? = nil
    var color: Color = .wikiAccent
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.25) : Color.wikiCard)
            .clipShape(Capsule())
            .foregroundStyle(isSelected ? color : .wikiSecondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
