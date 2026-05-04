// UndoService.swift
//
// 作者: Wang Chong
// 功能说明: Manages undo/redo for KMStore operations using snapshot-based approach.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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
