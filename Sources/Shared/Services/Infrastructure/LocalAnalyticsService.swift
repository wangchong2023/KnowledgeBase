// LocalAnalyticsService.swift
//
// 作者: Wang Chong
// 功能说明: 基础分析服务实现：目前仅打印日志，未来可接入端侧埋点或 Firebase
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 基础分析服务实现：目前仅打印日志，未来可接入端侧埋点或 Firebase
@MainActor
final class LocalAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    static let shared = LocalAnalyticsService()
    
    private let logURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logURL = docs.appendingPathComponent("analytics_log.json")
    }
    
    func trackEvent(_ name: String, properties: [String: Any]? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        // 1. 控制台实时反馈
        print("📊 [Analytics] \(timestamp) | \(name) | \(properties?.description ?? "")")
        
        let event: [String: Any] = [
            "name": name,
            "properties": properties ?? [:],
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 2. 持久化至沙盒 (异步追加)
        saveEventToFile(event)
    }
    
    private func saveEventToFile(_ event: [String: Any]) {
        // 先序列化为 Data，确保可以安全传递给后台线程
        guard let dataToSave = try? JSONSerialization.data(withJSONObject: event) else { return }
        let logURL = self.logURL
        
        DispatchQueue.global(qos: .utility).async {
            var logs: [[String: Any]] = []
            if let data = try? Data(contentsOf: logURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                logs = existing
            }
            
            if let newEvent = try? JSONSerialization.jsonObject(with: dataToSave) as? [String: Any] {
                logs.append(newEvent)
                if let updatedData = try? JSONSerialization.data(withJSONObject: logs, options: .prettyPrinted) {
                    try? updatedData.write(to: logURL)
                }
            }
        }
    }
    
    func trackError(_ error: Error, details: String? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("❌ [Analytics] \(timestamp) | Error: \(error.localizedDescription) | Details: \(details ?? "")")
    }
}
