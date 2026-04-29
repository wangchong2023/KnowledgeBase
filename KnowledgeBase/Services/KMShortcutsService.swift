import SwiftUI
import AppIntents

// MARK: - Search Wiki Intent
struct SearchWikiIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.searchWiki", table: nil)
    static var description = IntentDescription(LocalizedStringResource("shortcuts.searchWikiDesc", table: nil))
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: LocalizedStringResource("shortcuts.searchKeyword", table: nil))
    var query: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$query)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = KMStore()
        store.loadFromDisk()
        
        store.searchText = query
        let results = store.searchResults
        
        if results.isEmpty {
            return .result(value: String(format: L.tr("shortcuts.noResults"), query))
        }
        
        let titles = results.prefix(5).map { $0.title }
        let summary = String(format: L.tr("shortcuts.foundResults"), results.count) + ":\n" + titles.joined(separator: "、")
        return .result(value: summary)
    }
}

// MARK: - Get Wiki Stats Intent
struct GetWikiStatsIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.wikiStats", table: nil)
    static var description = IntentDescription(LocalizedStringResource("shortcuts.wikiStatsDesc", table: nil))
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = KMStore()
        store.loadFromDisk()
        
        let stats = String(format: L.tr("shortcuts.statsFormat"), store.totalPages, store.totalWords, store.entityCount, store.conceptCount, store.stubCount)
        
        return .result(value: stats)
    }
}

// MARK: - Create Wiki Page Intent
struct CreateWikiPageIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.createPage", table: nil)
    static var description = IntentDescription(LocalizedStringResource("shortcuts.createPageDesc", table: nil))
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: LocalizedStringResource("shortcuts.pageTitle", table: nil))
    var pageTitle: String
    
    @Parameter(title: LocalizedStringResource("shortcuts.pageContent", table: nil), default: "")
    var pageContent: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$pageTitle)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = KMStore()
        store.loadFromDisk()
        
        let page = store.createPage(title: pageTitle, type: .concept, content: pageContent)
        store.saveToDisk()
        
        return .result(value: String(format: L.tr("shortcuts.createdPage"), page.title))
    }
}

// MARK: - Knowledge Base Shortcuts Provider
struct KMShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchWikiIntent(),
            phrases: [
                "在\(.applicationName)中搜索知识库",
                "\(.applicationName)知识搜索"
            ],
            shortTitle: LocalizedStringResource("shortcuts.searchWiki", table: nil),
            systemImageName: "magnifyingglass"
        )
        
        AppShortcut(
            intent: GetWikiStatsIntent(),
            phrases: [
                "\(.applicationName)知识库统计",
                "\(.applicationName)统计"
            ],
            shortTitle: LocalizedStringResource("shortcuts.wikiStats", table: nil),
            systemImageName: "chart.bar"
        )
        
        AppShortcut(
            intent: CreateWikiPageIntent(),
            phrases: [
                "在\(.applicationName)中创建知识",
                "\(.applicationName)新建页面"
            ],
            shortTitle: LocalizedStringResource("shortcuts.createPage", table: nil),
            systemImageName: "plus.circle"
        )
    }
}
