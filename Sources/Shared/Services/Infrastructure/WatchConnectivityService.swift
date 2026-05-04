// WatchConnectivityService.swift
//
// 作者: Wang Chong
// 功能说明: 跨端通信服务 (Shared across iOS & watchOS)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
#if canImport(WatchConnectivity)
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
            WCSession.default.delegate = self
            WCSession.default.activate()
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
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            Task { @MainActor in
                LogService.shared.error("⌚ [WatchSync] 激活失败: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let content = userInfo["content"] as? String {
            Task { @MainActor in
                self.lastReceivedText = content
                // 触发主 App 存储逻辑（由 KMStore 监听）
                NotificationCenter.default.post(name: .didReceiveWatchContent, object: content)
            }
        }
    }
    
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate() // 重新激活
    }
    #endif
}

extension WatchConnectivityService: @unchecked Sendable {}
#endif

extension Notification.Name {
    static let didReceiveWatchContent = Notification.Name("didReceiveWatchContent")
}

