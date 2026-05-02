import SwiftUI

/// KMWatch 主界面 (Apple Watch)
/// 专注于极简查阅与快速采集。
struct WatchContentView: View {
    @EnvironmentObject var store: KMStore
    @State private var isShowingDictation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(Localized.tr("watch.recents"))) {
                    ForEach(store.pages.sorted(by: { $0.updated > $1.updated }).prefix(5)) { page in
                        NavigationLink(value: page) {
                            HStack {
                                Image(systemName: page.displayIcon)
                                    .foregroundStyle(page.type.themedColor)
                                    .accessibilityHidden(true)
                                Text(page.title)
                                    .font(.caption.weight(.medium))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(page.title)
                        }
                    }
                }
                
                Section {
                    Button(action: { isShowingDictation = true }) {
                        Label(Localized.tr("watch.capture"), systemImage: "mic.fill")
                            .foregroundStyle(.wikiAccent)
                    }
                }
            }
            .navigationTitle("智元")
            .navigationDestination(for: WikiPage.self) { page in
                WatchPageDetailView(page: page)
            }
            .sheet(isPresented: $isShowingDictation) {
                WatchDictationView()
            }
        }
    }
}

/// 手表端页面详情
struct WatchPageDetailView: View {
    let page: WikiPage
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(page.title)
                    .font(.headline)
                    .foregroundStyle(.wikiAccent)
                
                Divider()
                
                // 手表端仅显示摘要或精简内容
                Text(page.summary ?? page.content.prefix(200) + "...")
                    .font(.caption2)
            }
            .padding()
        }
    }
}
