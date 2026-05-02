import Foundation
import WatchConnectivity
import Combine

/// 跨端通信服务 (Shared across iOS & watchOS)
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityService()
    
    @Published var lastReceivedText: String = ""
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    /// 将采集到的内容发送到配对设备
    func sendContent(_ text: String) {
        guard WCSession.default.activationState == .activated else { return }
        
        // 使用 transferUserInfo 保证离线环境下的最终一致性
        let userInfo = ["type": "new_page", "content": text, "date": Date()] as [String : Any]
        WCSession.default.transferUserInfo(userInfo)
        
        LogService.shared.debug("⌚ [WatchSync] 已发起数据传输：\(text.prefix(10))...")
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            LogService.shared.error("⌚ [WatchSync] 激活失败: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let content = userInfo["content"] as? String {
            DispatchQueue.main.async {
                self.lastReceivedText = content
                // 触发主 App 存储逻辑（由 KMStore 监听）
                NotificationCenter.default.post(name: .didReceiveWatchContent, object: content)
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate() // 重新激活
    }
    #endif
}

extension Notification.Name {
    static let didReceiveWatchContent = Notification.Name("didReceiveWatchContent")
}
