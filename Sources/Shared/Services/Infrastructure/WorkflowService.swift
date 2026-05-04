// WorkflowService.swift
//
// 作者: Wang Chong
// 功能说明: 工作流服务：连接知识与外部系统（如提醒事项、日历）
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import EventKit

/// 工作流服务：连接知识与外部系统（如提醒事项、日历）
@MainActor
final class WorkflowService: ObservableObject {
    static let shared = WorkflowService()
    private let eventStore = EKEventStore()
    
    enum WorkflowError: Error {
        case accessDenied
        case saveFailed
    }
    
    /// 请求提醒事项权限
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            return false
        }
    }
    
    /// 将 AI 提取的行动项同步至系统提醒事项
    /// - Parameters:
    ///   - text: 包含任务的文本（通常是 AI 生成的 Markdown 列表）
    ///   - title: 提醒事项列表的标题
    func syncToReminders(text: String, title: String) async throws {
        let hasAccess = await requestAccess()
        guard hasAccess else { throw WorkflowError.accessDenied }
        
        // 解析 Markdown 任务列表（匹配 - [ ] 或 - ）
        let lines = text.components(separatedBy: .newlines)
        let tasks = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }
            .map { line -> String in
                line.replacingOccurrences(of: "- [ ] ", with: "")
                    .replacingOccurrences(of: "- [x] ", with: "")
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        
        for task in tasks {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = task
            reminder.notes = "来自智元：\(title)"
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
            
            try eventStore.save(reminder, commit: true)
        }
        
        HapticManager.shared.trigger(.success)
    }
}
