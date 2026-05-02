import Foundation

/// 基础分析服务实现：目前仅打印日志，未来可接入端侧埋点或 Firebase
final class LocalAnalyticsService: AnalyticsServiceProtocol {
    static let shared = LocalAnalyticsService()
    
    private let logURL: URL
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logURL = docs.appendingPathComponent("analytics_log.json")
    }
    
    func trackEvent(_ name: String, properties: [String: Any]? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let event: [String: Any] = [
            "event": name,
            "timestamp": Date().timeIntervalSince1970,
            "properties": properties ?? [:]
        ]
        
        // 1. 控制台实时反馈
        print("📊 [Analytics] \(timestamp) | \(name) | \(properties?.description ?? "")")
        
        // 2. 持久化至沙盒 (异步追加)
        saveEventToFile(event)
    }
    
    private func saveEventToFile(_ event: [String: Any]) {
        DispatchQueue.global(qos: .utility).async {
            var logs: [[String: Any]] = []
            if let data = try? Data(contentsOf: self.logURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                logs = existing
            }
            logs.append(event)
            if let updatedData = try? JSONSerialization.data(withJSONObject: logs, options: .prettyPrinted) {
                try? updatedData.write(to: self.logURL)
            }
        }
    }
    
    func trackError(_ error: Error, details: String? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("❌ [Analytics] \(timestamp) | Error: \(error.localizedDescription) | Details: \(details ?? "")")
    }
}
