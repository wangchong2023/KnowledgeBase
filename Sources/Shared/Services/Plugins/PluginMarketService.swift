// PluginMarketService.swift
//
// 作者: Wang Chong
// 功能说明: 插件市场条目模型
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import Combine

/// 插件市场条目模型
@MainActor
struct MarketPlugin: Codable, Identifiable {
    let id: String
    let name: String
    let author: String
    let description: String
    let version: String
    let downloads: String
    let rating: Double
    let icon: String
    let minAppVersion: String?
    let requiredPermissions: [PluginPermission]?
    let monetization: MonetizationInfo?
}

/// 插件市场服务 (Architect 视角：实现云端分发体系)
final class PluginMarketService: ObservableObject {
    @Published var availablePlugins: [MarketPlugin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // 生产环境地址 (GitHub 模式)
    private let productionURL = URL(string: AppConfig.productionURL)!
    
    // 本地调试地址 (开发者模式)
    private let debugURL = URL(string: AppConfig.mockServerURL)!
    
    private var targetURL: URL {
        #if DEBUG
        return debugURL
        #else
        return productionURL
        #endif
    }
    
    func fetchPlugins() async {
        await MainActor.run { 
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 真实的网络请求逻辑
            let (data, _) = try await URLSession.shared.data(from: targetURL)
            let decoder = JSONDecoder()
            let decodedPlugins = try decoder.decode([MarketPlugin].self, from: data)
            
            await MainActor.run {
                self.availablePlugins = decodedPlugins
                self.isLoading = false
            }
        } catch {
            Logger.shared.addLog(action: .error, target: "PluginMarketService", details: "获取插件失败: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = Localized.tr("plugin.market.connectionError")
                self.isLoading = false
            }
        }
    }
}

extension PluginMarketService: @unchecked Sendable {}
