// KMKeyboardShortcuts.swift
//
// 作者: Wang Chong
// 功能说明: Centralized keyboard shortcuts configuration for KM
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Keyboard Shortcuts Manager
/// Centralized keyboard shortcuts configuration for KM
/// Supports Mac Catalyst with proper modifier flags
enum KMKeyboardShortcuts {
    // MARK: - Modifier Keys
    static let commandModifiers: EventModifiers = .command
    static let shiftCommandModifiers: EventModifiers = [.command, .shift]

    // MARK: - Shortcut Actions
    enum Action {
        case newPage
        case search
        case undo
        case redo
        case save
        case closeWindow
        case openSettings
        case quit
    }

    /// Get keyboard shortcut key for action
    static func shortcutKey(for action: Action) -> String? {
        switch action {
        case .newPage: return "n"
        case .search: return "f"
        case .undo: return "z"
        case .redo: return "Z"
        case .save: return "s"
        case .closeWindow: return "w"
        case .openSettings: return ","
        case .quit: return "q"
        }
    }

    /// Get modifier flags for action
    static func modifiers(for action: Action) -> EventModifiers {
        switch action {
        case .newPage, .search, .save, .closeWindow, .openSettings:
            return commandModifiers
        case .undo, .quit:
            return commandModifiers
        case .redo:
            return shiftCommandModifiers
        }
    }
}

// MARK: - Keyboard Shortcuts View Modifier
struct KeyboardShortcutsViewModifier: ViewModifier {
    @Environment(KMStore.self) var store
    @State private var showCreateSheet = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCreateSheet) {
                CreatePageView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNewPage)) { _ in
                showCreateSheet = true
            }
    }
}

extension View {
    func withKeyboardShortcuts() -> some View {
        modifier(KeyboardShortcutsViewModifier())
    }
}

// MARK: - Notification Names for Keyboard Shortcuts
extension Notification.Name {
    static let createNewPage = Notification.Name("KMCreateNewPage")
    static let performSave = Notification.Name("KMPerformSave")
    static let focusSearch = Notification.Name("KMFocusSearch")
    static let performUndo = Notification.Name("KMPerformUndo")
    static let performRedo = Notification.Name("KMPerformRedo")
    static let closeWindow = Notification.Name("KMCloseWindow")
    static let openSettings = Notification.Name("KMOpenSettings")
    static let quitApp = Notification.Name("KMQuitApp")
}