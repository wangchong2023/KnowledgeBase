// UndoService.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的撤销/重做管理服务（UndoService），基于快照（Snapshot）模式保障用户操作的可追溯性与数据安全性。
// 该服务作为数据修改流水线的安全阀，通过以下核心功能点提升系统的容错能力：
// 1. 全量快照状态追踪：在每次核心数据变更前自动捕获当前知识库的完整快照，支持对复杂编辑行为的精准回滚。
// 2. 双栈历史管理：维护独立且同步的撤销（Undo）与重做（Redo）栈，支持深度达 50 级的操作回溯。
// 3. 反应式状态感知：实时导出 canUndo 与 canRedo 状态，驱动 UI 层撤销按钮的动态可用性反馈。
// 4. 智适应内存控制：内置栈空间限制与自动修剪机制，平衡了操作回溯深度与系统内存开销，确保长周期运行下的系统稳定性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化快照管理与状态机说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import Combine

// MARK: - Undo Service
/// Manages undo/redo for KMStore operations using snapshot-based approach.
/// Each mutation saves a snapshot of pages before the change, enabling full rollback.
final class UndoService: ObservableObject {
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    private var undoStack: [[WikiPage]] = []
    private var redoStack: [[WikiPage]] = []
    private let maxStackSize = 50
    
    // MARK: - Snapshot Management
    func pushSnapshot(_ pages: [WikiPage]) {
        undoStack.append(pages.map { $0 })
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        // Any new action clears the redo stack
        redoStack.removeAll()
        updatePublishedState()
    }
    
    func undo(currentPages: [WikiPage]) -> [WikiPage]? {
        guard !undoStack.isEmpty else { return nil }
        // Save current state to redo stack
        redoStack.append(currentPages.map { $0 })
        let previous = undoStack.removeLast()
        updatePublishedState()
        return previous
    }
    
    func redo(currentPages: [WikiPage]) -> [WikiPage]? {
        guard !redoStack.isEmpty else { return nil }
        // Save current state to undo stack
        undoStack.append(currentPages.map { $0 })
        let next = redoStack.removeLast()
        updatePublishedState()
        return next
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updatePublishedState()
    }
    
    private func updatePublishedState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
