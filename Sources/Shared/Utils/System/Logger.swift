// Logger.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了全站通用的日志记录系统（Logger），旨在为系统提供统一、高性能且具备持久化能力的审计与调试支持。
// 该组件通过以下核心功能点保障系统的可观测性：
// 1. 实现分级日志管理（Debug/Error），支持根据编译环境自动切换输出策略，优化生产环境性能。
// 2. 提供基于磁盘持久化的审计日志系统，通过 JSON 序列化技术将操作记录保存至应用沙盒，支持多级缓冲与异步保存。
// 3. 集成 Combine 框架，通过发布者-订阅者模式实时推送日志更新，驱动 UI 层的审计中心进行响应式渲染。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/System 并重构为核心工具类，强化了功能说明注释
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import Combine

// MARK: - Models

/// 审计日志条目模型，记录系统操作的元数据
struct LogEntry: Identifiable, Codable {
    var id: UUID
    var action: LogAction
    var target: String
    var details: String
    var timestamp: Date
    var duration: TimeInterval?
    var startTime: Date?
    var endTime: Date?
    var module: String? // 来源模块，如 SystemVault, KMStore
    
    init(
        id: UUID = UUID(),
        action: LogAction,
        target: String,
        details: String = "",
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
        self.timestamp = timestamp
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.module = module
    }
}

/// 日志记录协议，定义日志输出与持久化的核心行为
protocol LoggerProtocol: AnyObject, Sendable {
    var logEntries: [LogEntry] { get }
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { get }
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?)
    func debug(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
    func saveToDisk()
    func loadFromDisk()
    func clearAllLogs()
}

extension LoggerProtocol {
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.debug(message, file: file, function: function, line: line)
    }
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, file: file, function: function, line: line)
    }
    
    /// 提供 addLog 的默认参数支持
    func addLog(
        action: LogAction,
        target: String,
        details: String = "",
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil
    ) {
        self.addLog(action: action, target: target, details: details, duration: duration, startTime: startTime, endTime: endTime, module: module)
    }
}

// MARK: - Logger (Standardized Logging)
/// [L1] 基础层：管理审计日志的持久化与内存缓存
final class Logger: ObservableObject, LoggerProtocol, @unchecked Sendable {
    static let shared = Logger() // 全局共享实例
    
    @Published var logEntries: [LogEntry] = []
    
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> {
        $logEntries.eraseToAnyPublisher()
    }
    
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
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
        addLog(action: .error, target: fileName, details: "\(message): \(errorDesc)")
    }

    private let logKey = "knowledge-management_logs"
    private let customDirectory: URL?
    
    private var documentsDirectory: URL {
        customDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var logsFileURL: URL {
        documentsDirectory.appendingPathComponent(AppConfig.logsFileName)
    }
    
    // MARK: - Constants
    /// Maximum number of log entries to retain
    private static let maxLogEntries = 500
    
    // MARK: - Init
    init(customDirectory: URL? = nil) {
        self.customDirectory = customDirectory
        loadFromDisk()
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // 使用异步 Task 以安全访问 MainActor 隔离的 WikiEventBus
        Task { @MainActor in
            WikiEventBus.shared.subscribe()
                .receive(on: RunLoop.main)
                .sink { [weak self] event in
                    if case .clearAllDataRequested = event {
                        self?.clearAllLogs()
                    }
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Add Entry
    func addLog(
        action: LogAction,
        target: String,
        details: String = "",
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil
    ) {
        let entry = LogEntry(
            action: action,
            target: target,
            details: details,
            duration: duration,
            startTime: startTime,
            endTime: endTime,
            module: module
        )
        Task { @MainActor in
            logEntries.insert(entry, at: 0)
            if logEntries.count > AppConfig.maxLogEntries { 
                logEntries = Array(logEntries.prefix(AppConfig.maxLogEntries)) 
            }
            saveToDisk()
        }
    }

    // MARK: - Persistence
    func saveToDisk() {
        // 在主线程捕获快照，避免竞态
        let entries = self.logEntries
        
        DispatchQueue.global(qos: .background).async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            do {
                let data = try encoder.encode(entries)
                try data.write(to: self.logsFileURL, options: .atomicWrite)
            } catch {
                print("❌ [Logger] Failed to save logs: \(error.localizedDescription)")
            }
        }
    }

    func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: logsFileURL)
            let loadedEntries = try decoder.decode([LogEntry].self, from: data)
            Task { @MainActor in
                self.logEntries = loadedEntries
            }
        } catch {
            // Try migrating from UserDefaults
            if let data = UserDefaults.standard.data(forKey: logKey),
               let decoded = try? decoder.decode([LogEntry].self, from: data) {
                Task { @MainActor in
                    self.logEntries = decoded
                    self.saveToDisk()
                    UserDefaults.standard.removeObject(forKey: self.logKey)
                }
            }
        }
    }

    func clearAllLogs() {
        Task { @MainActor in
            logEntries.removeAll()
            saveToDisk()
        }
    }
}
