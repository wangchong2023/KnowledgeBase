// WorkflowService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的工作流自动化服务（WorkflowService），作为应用内部知识与外部系统生态（如 Apple 提醒事项、日历）之间的交互枢纽。
// 该服务致力于将静态知识转化为可执行的行动力，核心功能点如下：
// 1. 系统级能力集成：基于 EventKit 框架实现了与 macOS/iOS 原生提醒事项的深度集成，支持全量访问权限的智能请求。
// 2. 智能任务解析：内置 Markdown 任务提取引擎，能够自动识别 AI 生成内容中的待办事项（如 - [ ] 标记），并将其无损转化为系统级提醒。
// 3. 跨应用上下文同步：在建立提醒事项时自动注入知识库来源（Context），确保用户在处理任务时能快速回溯至对应的 Wiki 页面。
// 4. 闭环反馈机制：通过 HapticFeedback 建立操作反馈，确保任务同步过程的感知可靠性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，完善 EventKit 集成与任务解析逻辑说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
            reminder.notes = "来自智宇：\(title)"
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
            
            try eventStore.save(reminder, commit: true)
        }
        
        HapticFeedback.shared.trigger(.success)
    }
}
