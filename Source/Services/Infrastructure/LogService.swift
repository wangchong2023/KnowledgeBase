import Foundation
import Combine

/// 日志服务协议，定义审计日志的核心行为
protocol LogServiceProtocol: AnyObject {
    var logEntries: [LogEntry] { get }
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { get }
    func addLog(action: String, target: String, details: String)
    func debug(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
    func saveToDisk()
    func loadFromDisk()
}

extension LogServiceProtocol {
    /// 默认实现，简化调用
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, file: file, function: function, line: line)
    }
}

// MARK: - Log Service (Operation Logging)
/// [L1] 领域层：管理审计日志的持久化与内存缓存
final class LogService: ObservableObject, LogServiceProtocol {
    static let shared = LogService() // 全局共享实例 (用于底层非注入场景)
    
    @Published var logEntries: [LogEntry] = []
    
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> {
        $logEntries.eraseToAnyPublisher()
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("🔍 [DEBUG] [\(fileName):\(line)] \(function) -> \(message)")
        #endif
    }
    
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let errorDesc = error?.localizedDescription ?? "None"
        print("❌ [ERROR] [\(fileName):\(line)] \(function) -> \(message) (Error: \(errorDesc))")
        
        // 重要错误也记录到审计日志
        addLog(action: "ERROR", target: fileName, details: "\(message): \(errorDesc)")
    }

    private let logKey = "knowledge-management_logs"
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var logsFileURL: URL {
        documentsDirectory.appendingPathComponent(AppConfig.logsFileName)
    }
    
    // MARK: - Constants
    /// Maximum number of log entries to retain
    private static let maxLogEntries = 500
    
    // MARK: - Init
    init() {
        loadFromDisk()
    }

    // MARK: - Add Entry
    func addLog(action: String, target: String, details: String = "") {
        let entry = LogEntry(action: action, target: target, details: details)
        logEntries.insert(entry, at: 0)
        if logEntries.count > AppConfig.maxLogEntries { 
            logEntries = Array(logEntries.prefix(AppConfig.maxLogEntries)) 
        }
        saveToDisk()
    }

    // MARK: - Persistence
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(logEntries)
            try data.write(to: logsFileURL, options: .atomicWrite)
        } catch {
            print(String(format: Localized.tr("log.error.saveFailed"), error.localizedDescription))
        }
    }

    func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: logsFileURL)
            logEntries = try decoder.decode([LogEntry].self, from: data)
        } catch {
            // Try migrating from UserDefaults
            if let data = UserDefaults.standard.data(forKey: logKey),
               let decoded = try? decoder.decode([LogEntry].self, from: data) {
                logEntries = decoded
                saveToDisk()
                UserDefaults.standard.removeObject(forKey: logKey)
            }
        }
    }
}
