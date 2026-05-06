// ReadabilityModifiers.swift
//
// 作者: Wang Chong
// 功能说明: iPad 大屏幕下约束内容最大宽度（680pt），居中显示
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Readable Content Width Modifier
/// iPad 大屏幕下约束内容最大宽度（680pt），居中显示
/// iPhone 或紧凑宽度下保持全宽
struct ReadableContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 最大内容宽度
    private let maxWidth: CGFloat = 680

    /// 是否在 iPad/大屏幕启用宽度约束
    private var isEnabled: Bool {
        horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .frame(maxWidth: maxWidth, alignment: .center)
        } else {
            content
        }
    }
}

// MARK: - Convenience Extension
extension View {
    /// 包装内容在大屏幕下限制宽度为 680pt 并居中
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidth())
    }
}