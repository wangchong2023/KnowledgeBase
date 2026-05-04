// PluginCenterView.swift
//
// 作者: Wang Chong
// 功能说明: 插件中心 (Stub: 为未来生态预留位置)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// 插件中心 (Stub: 为未来生态预留位置)
struct PluginCenterView: View {
    @StateObject private var registry = PluginRegistry.shared
    @StateObject private var marketService = PluginMarketService()
    
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSafeModeOn = true
    @State private var showFileImporter = false
    
    var body: some View {
        ZStack {
            Color.wikiBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 高级搜索与筛选头部
                headerSection
                
                // 2. 分段切换 (带动效)
                Picker("", selection: $selectedTab) {
                    Text(Localized.tr("plugin.market")).tag(0)
                    Text(Localized.tr("plugin.myPlugins")).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 3. 内容主体
                ScrollView {
                    if selectedTab == 0 {
                        marketSection
                    } else {
                        myPluginsSection
                    }
                }
            }
        }
        .navigationTitle(Localized.tr("plugin.center"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            // 处理文件选择结果
        }
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
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.wikiBorder.opacity(0.5), lineWidth: 0.5))
            
            // 安全模式与加载按钮：左对齐，去冗余
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text(Localized.tr("plugin.safeMode"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.wikiSecondary)
                    Toggle("", isOn: $isSafeModeOn)
                        .labelsHidden()
                        .controlSize(.mini)
                        .scaleEffect(0.85) // 缩小开关尺寸
                        .tint(.wikiAccent)
                }
                
                Button(action: { 
                    HapticManager.shared.trigger(.selection)
                    showFileImporter = true 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text(Localized.tr("plugin.local.mount"))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.wikiAccent.opacity(0.1))
                    .foregroundStyle(Color.wikiAccent)
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color.wikiBackground)
    }
    
    private var myPluginsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            let filtered = registry.plugins.filter { searchText.isEmpty || $0.manifest.name.localizedCaseInsensitiveContains(searchText) }
            
            if !filtered.isEmpty {
                Text(Localized.tr("plugin.status.enabled"))
                    .font(.caption.bold())
                    .foregroundStyle(.wikiSecondary)
                    .padding(.horizontal)
                
                ForEach(filtered, id: \.manifest.id) { plugin in
                    PluginCard(name: plugin.manifest.name, version: plugin.manifest.version, isLocal: true)
                }
                .padding(.horizontal)
            } else if searchText.isEmpty {
                // 如果没有插件且不在搜索状态，显示空状态
                emptyStateView(icon: "puzzlepiece", title: Localized.tr("plugin.noPlugins"), sub: Localized.tr("plugin.noPluginsHint"))
            } else {
                // 搜索结果为空
                emptyStateView(icon: "magnifyingglass", title: Localized.tr("plugin.noResults"), sub: Localized.tr("plugin.noResultsHint"))
            }
        }
    }
    
    private var marketSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if marketService.isLoading {
                ProgressView().padding(.top, 50).frame(maxWidth: .infinity)
            } else {
                let filtered = marketService.availablePlugins.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                
                if filtered.isEmpty {
                    emptyStateView(icon: "storefront", title: Localized.tr("plugin.market.empty"), sub: Localized.tr("plugin.market.emptyHint"))
                } else {
                    ForEach(filtered) { p in
                        NavigationLink(destination: PluginDetailView(name: p.name, author: p.author, version: p.version, description: p.description, icon: p.icon)) {
                            PluginCard(name: p.name, version: p.version, author: p.author, downloads: p.downloads, rating: p.rating, icon: p.icon)
                        }
                    }
                    .padding(.horizontal)
                }
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
