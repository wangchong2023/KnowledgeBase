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
            print("❌ [Market] 获取插件失败: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "无法连接至插件市场 (影子服务器)，请确保已启动 python3 -m http.server 8000"
                self.isLoading = false
            }
        }
    }
}
