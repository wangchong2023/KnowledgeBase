// WikiColors.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了知识管理系统的核心调色盘与语义化颜色系统（WikiColors），作为 UI 组件样式的唯一可信源。
// 该颜色系统基于 SwiftUI 环境分发机制，构建了一套智适应的视觉设计语言，核心功能点如下：
// 1. 动态语义化映射：定义了 wikiBackground、wikiCard、wikiText 等语义化颜色 Token，自动适配 macOS/iOS 的深浅色外观切换。
// 2. 知识维度色彩标识：为 PageType（如实体、概念、对比等）分配专属的视觉标识色，辅助用户通过色彩直观识别知识属性。
// 3. 高性能环境注入：利用 WikiAccentColorKey 实现品牌色在 View 树中的响应式向下传播，确保全局主题变更的流畅性。
// 4. 健壮的 HEX 解析与桥接：内置高效的 HEX 颜色转换引擎及 UIKit/AppKit 色彩桥接逻辑，解决跨平台环境下的色彩渲染一致性问题。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，规范化语义颜色定义与跨平台适配逻辑
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Wiki Accent Color Environment Key
private struct WikiAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.blue
}

extension EnvironmentValues {
    /// The current wiki accent color, propagated through the SwiftUI environment.
    /// Updated by KMApp whenever the user changes the theme color.
    var wikiAccentColor: Color {
        get { self[WikiAccentColorKey.self] }
        set { self[WikiAccentColorKey.self] = newValue }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Knowledge Base Color Palette
extension Color {
    // Adaptive initializer — must precede static let declarations (Swift 6 compiler bug workaround)
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }

    // Adaptive colors that respond to light/dark mode
    // Uses computed properties to work around a Swift 6 compiler bug with static let + custom Color init
    static var wikiBackground: Color {
        Color(light: Color(hex: "f5f5fa"), dark: Color(hex: "1a1b2e"))
    }
    static var wikiCard: Color {
        Color(light: Color(hex: "ffffff"), dark: Color(hex: "252640"))
    }

    // Dynamic accent color: reads from ThemeManager's cached value.
    // Uses the shared ThemeManager singleton for consistency and caching.
    // Views should prefer @Environment(\.wikiAccentColor) for the best performance.
    static var wikiAccent: Color {
        // ThemeManager.shared 是 @MainActor 隔离的。
        // 在 UI 代码中，这里通常在主线程运行。
        MainActor.assumeIsolated {
            ThemeManager.shared.accentColor
        }
    }

    static var wikiText: Color {
        Color(light: Color(hex: "1a1a2e"), dark: Color(hex: "e8e8f0"))
    }
    static var wikiSecondary: Color {
        Color(light: Color(hex: "6b6b87"), dark: Color(hex: "8b8ba7"))
    }
    static var wikiBorder: Color {
        Color(light: Color(hex: "ebebf2"), dark: Color(hex: "303142"))
    }
    
    /// 页面主容器的柔和描边颜色
    static var wikiMainBorder: Color {
        Color(light: Color(hex: "d1d1e0"), dark: Color(hex: "40415a"))
    }

    static var wikiEntity: Color {
        Color(light: Color(hex: "3a8aee"), dark: Color(hex: "4a9eff"))
    }
    static var wikiConcept: Color {
        Color(light: Color(hex: "9a4ee6"), dark: Color(hex: "b46eff"))
    }
    static var wikiSource: Color {
        Color(light: Color(hex: "3ab8b0"), dark: Color(hex: "4ecdc4"))
    }
    static var wikiComparison: Color {
        Color(light: Color(hex: "ee8a30"), dark: Color(hex: "ff9f43"))
    }
    static var wikiMap: Color {
        Color(light: Color(hex: "ee5555"), dark: Color(hex: "ff6b6b"))
    }
    static var wikiRaw: Color {
        Color(light: Color(hex: "7a8a8c"), dark: Color(hex: "95a5a6"))
    }

}

// MARK: - Page Type Color Helper
extension PageType {
    var themedColor: Color {
        switch self {
        case .entity: return .wikiEntity
        case .concept: return .wikiConcept
        case .source: return .wikiSource
        case .comparison: return .wikiComparison
        case .map: return .wikiMap
        case .raw: return .wikiRaw
        }
    }
}

// MARK: - View Extension for Adaptive Backgrounds
extension View {
    func wikiAdaptiveBackground() -> some View {
        self.background(Color.wikiBackground)
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        transform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            transform(self)
        } else {
            elseTransform(self)
        }
    }
}

// MARK: - ShapeStyle Extension for Color Access
// Allows .foregroundStyle(.wikiText) syntax
extension ShapeStyle where Self == Color {
    static var wikiBackground: Color { Color.wikiBackground }
    static var wikiCard: Color { Color.wikiCard }
    static var wikiAccent: Color { Color.wikiAccent }
    static var wikiText: Color { Color.wikiText }
    static var wikiSecondary: Color { Color.wikiSecondary }
    static var wikiBorder: Color { Color.wikiBorder }
    static var wikiMainBorder: Color { Color.wikiMainBorder }
    static var wikiEntity: Color { Color.wikiEntity }
    static var wikiConcept: Color { Color.wikiConcept }
    static var wikiSource: Color { Color.wikiSource }
    static var wikiComparison: Color { Color.wikiComparison }
    static var wikiMap: Color { Color.wikiMap }
    static var wikiRaw: Color { Color.wikiRaw }
}
