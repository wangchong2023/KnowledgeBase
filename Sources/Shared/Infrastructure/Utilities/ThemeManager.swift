// ThemeManager.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的全局主题治理与视觉偏好配置服务（ThemeManager），负责跨平台的视觉风格协调与动态样式注入。
// 该服务作为 UI 表现层的基座，通过以下核心功能点确保系统的美学一致性与个性化体验：
// 1. 智适应色彩方案：支持深色（Dark）、浅色（Light）及跟随系统的主题模式切换，并内置了从旧版 isDarkMode 标志位的全量迁移逻辑。
// 2. 动态品牌色系统：管理应用的核心强调色（Accent Color），支持在运行时实时更新并广播至所有底层组件。
// 3. 反应式状态分发：基于 @AppStorage 与 ObservableObject 实现了偏好项的持久化与 UI 自动重绘，解耦了业务视图与样式配置。
// 4. 跨平台语义映射：提供颜色名称与系统 Color 对象的安全转换接口，确保在不同操作系统环境下均能获得最佳的视觉对比度。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，完善主题迁移逻辑与色彩管理说明
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("colorSchemeMode") var colorSchemeModeRaw: String = ColorSchemeMode.dark.rawValue
    nonisolated var accentColorRaw: String {
        get { UserDefaults.standard.string(forKey: "accentColor") ?? "blue" }
    }

    /// Migrate legacy isDarkMode key on first access
    private nonisolated(unsafe) static var didMigrate = false

    var colorSchemeMode: ColorSchemeMode {
        get {
            if !Self.didMigrate {
                Self.didMigrate = true
                // Migrate: if old key exists and new key is default
                if UserDefaults.standard.object(forKey: "isDarkMode") != nil,
                   UserDefaults.standard.string(forKey: "colorSchemeMode") == nil {
                    let wasDark = UserDefaults.standard.bool(forKey: "isDarkMode")
                    colorSchemeModeRaw = wasDark ? ColorSchemeMode.dark.rawValue : ColorSchemeMode.light.rawValue
                    UserDefaults.standard.removeObject(forKey: "isDarkMode")
                }
            }
            return ColorSchemeMode(rawValue: colorSchemeModeRaw) ?? .dark
        }
        set {
            colorSchemeModeRaw = newValue.rawValue
        }
    }

    /// Live color: reads from UserDefaults on every access (no cache).
    /// @AppStorage already handles observation via Combine.
    nonisolated var accentColor: Color {
        ThemeManager.colorForName(accentColorRaw)
    }

    func setAccentColor(_ color: String) {
        UserDefaults.standard.set(color, forKey: "accentColor")
        objectWillChange.send()
    }

    /// Maps a color name string (stored in UserDefaults) to a system Color.
    nonisolated static func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
    }

    /// Instance method wrapper for convenience.
    nonisolated func colorForName(_ name: String) -> Color {
        Self.colorForName(name)
    }
}

extension ThemeManager: @unchecked Sendable {}
