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
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine

/// 日志记录协议，定义日志输出与持久化的核心行为
protocol LoggerProtocol: AnyObject, Sendable {
    var logEntries: [LogEntry] { get }
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { get }
    func addLog(action: LogAction, target: String, details: String)
    func debug(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
    func saveToDisk()
    func loadFromDisk()
    func clearAllLogs()
}

extension LoggerProtocol {
    /// 默认实现，简化调用
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.debug(message, file: file, function: function, line: line)
    }
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, file: file, function: function, line: line)
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
    }

    // MARK: - Add Entry
    func addLog(action: LogAction, target: String, details: String = "") {
        let entry = LogEntry(action: action, target: target, details: details)
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
            // 异步执行磁盘操作，避免阻塞主线程
            DispatchQueue.global(qos: .background).async {
                self.saveToDisk()
            }
        }
    }
}
