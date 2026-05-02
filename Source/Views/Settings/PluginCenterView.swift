import SwiftUI

/// 插件中心 (Stub: 为未来生态预留位置)
struct PluginCenterView: View {
    @StateObject private var registry = PluginRegistry.shared
    @StateObject private var marketService = PluginMarketService()
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSafeModeOn = true
    
    var body: some View {
        ZStack {
            Color.wikiBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 高级搜索与筛选头部
                headerSection
                
                // 2. 分段切换 (带动效)
                Picker("", selection: $selectedTab) {
                    Text(Localized.tr("plugin.myPlugins")).tag(0)
                    Text(Localized.tr("plugin.market")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 3. 内容主体
                ScrollView {
                    if selectedTab == 0 {
                        myPluginsSection
                    } else {
                        marketSection
                    }
                }
            }
        }
        .navigationTitle(Localized.tr("plugin.center"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 搜索框：玻璃拟态
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.wikiAccent)
                TextField(Localized.tr("plugin.searchPlaceholder"), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.wikiAccent.opacity(0.2), lineWidth: 1))
            
            // 安全模式：呼吸感提醒
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isSafeModeOn ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .shadow(color: (isSafeModeOn ? Color.green : Color.orange).opacity(0.5), radius: 3)
                    Text(isSafeModeOn ? Localized.tr("plugin.safeModeOn") : Localized.tr("plugin.communityMode"))
                        .font(.caption2.bold())
                        .foregroundStyle(isSafeModeOn ? .green : .orange)
                }
                Spacer()
                Toggle("", isOn: $isSafeModeOn)
                    .labelsHidden()
                    .controlSize(.mini)
                    .tint(.wikiAccent)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color.wikiCard.opacity(0.4))
    }
    
    private var myPluginsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 本地加载卡片
            Button(action: { HapticManager.shared.trigger(.selection) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Localized.tr("plugin.local.mount")).font(.headline)
                        Text(Localized.tr("plugin.local.desc")).font(.caption2).foregroundStyle(.wikiSecondary)
                    }
                    Spacer()
                    Image(systemName: "plus.viewfinder").font(.title2)
                }
                .padding()
                .background(Color.wikiAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wikiAccent.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal)
            
            Text(Localized.tr("plugin.status.enabled"))
                .font(.caption.bold())
                .foregroundStyle(.wikiSecondary)
                .padding(.horizontal)
            
            let filtered = registry.plugins.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            
            if filtered.isEmpty {
                emptyStateView(icon: "puzzlepiece", title: Localized.tr("plugin.noPlugins"), sub: Localized.tr("plugin.noPluginsHint"))
            } else {
                ForEach(filtered, id: \.id) { plugin in
                    PluginCard(name: plugin.name, version: plugin.version, isLocal: true)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var marketSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if marketService.isLoading {
                ProgressView().padding(.top, 50).frame(maxWidth: .infinity)
            } else {
                let filtered = marketService.availablePlugins.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                
                ForEach(filtered) { p in
                    NavigationLink(destination: PluginDetailView(name: p.name, author: p.author, version: p.version, description: p.description, icon: p.icon)) {
                        PluginCard(name: p.name, version: p.version, author: p.author, downloads: p.downloads, rating: p.rating, icon: p.icon)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.wikiSecondary.opacity(0.3))
            Text(title).font(.headline).foregroundStyle(.wikiSecondary)
            Text(sub).font(.caption2).foregroundStyle(.wikiSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

struct PluginCard: View {
    let name: String
    let version: String
    var author: String? = nil
    var downloads: String? = nil
    var rating: Double? = nil
    var icon: String = "puzzlepiece.fill"
    var isLocal: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Color.wikiAccent, Color.wikiAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.subheadline.bold()).foregroundStyle(.wikiText)
                HStack(spacing: 8) {
                    Text("v\(version)").font(.caption2).foregroundStyle(.wikiSecondary)
                    if let author = author {
                        Text("•").font(.caption2).foregroundStyle(.wikiSecondary)
                        Text(author).font(.caption2).foregroundStyle(.wikiSecondary)
                    }
                }
                
                if let downloads = downloads, let rating = rating {
                    HStack(spacing: 8) {
                        Label(downloads, systemImage: "arrow.down.circle").font(.system(size: 10))
                        Label(String(format: "%.1f", rating), systemImage: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                    }
                    .foregroundStyle(.wikiSecondary)
                    .padding(.top, 2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.wikiSecondary)
        }
        .padding()
        .background(Color.wikiCard.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
