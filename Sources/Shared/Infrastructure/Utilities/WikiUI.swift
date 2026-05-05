// WikiUI.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了知识管理系统的统一 UI 规范库（WikiUI），旨在通过集中管理的语义化常量替换全工程中的硬编码数值。
// 该规范库涵盖了从原子级视觉单位到复杂交互参数的完整定义：
// 1. 栅格系统与圆角：提供了微型（Tiny）、小型（Small）、中型（Medium）及大型（Large）四档标准化圆角与内边距，确保界面节奏的一致性。
// 2. 字体等级：除了标准的系统字体映射外，通过标题等级枚举规范了 Markdown 文档的标题层级关系，支持跨平台的视觉对齐。
// 3. 物理仿真参数：定义了知识图谱布局引擎所需的收敛阈值、缩放边界及力导向常数，确保图谱在大规模节点下的交互稳定性。
// 4. 颜色与特效语义：封装了渐变色位置、阴影半径及动画时长，为系统各组件提供统一的视觉反馈深度。
// 版本: 1.2
// 修改记录:
//   - 2026-05-05: 升级为全系统 UI 规范基座，完善标题枚举与物理常数
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 智元 UI 常量规范
/// 集中管理的 UI 设计常量，用于替换工程中散落的硬编码数值。
enum WikiUI {
    // MARK: - 布局与圆角
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let giant: CGFloat = 24
    static let chipRadius: CGFloat = 20

    static let cardRadius: CGFloat = medium
    static let standardRadius: CGFloat = small
    static let smallRadius: CGFloat = small
    static let mediumRadius: CGFloat = medium
    static let largeRadius: CGFloat = large
    static let microRadius: CGFloat = tiny

    // MARK: - 间距与内边距
    static let standardPadding: CGFloat = 16
    static let widePadding: CGFloat = 20
    static let tightPadding: CGFloat = 8
    static let cardPadding: CGFloat = standardPadding
    static let sectionPadding: CGFloat = widePadding

    // MARK: - 动画曲线
    static let standardAnimation: Animation = .easeInOut(duration: 0.25)
    static let quickAnimation: Animation = .easeInOut(duration: 0.15)
    static let springAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    // MARK: - 图标与组件尺寸
    static let microIconSize: CGFloat = 12
    static let captionIconSize: CGFloat = 16
    static let titleIconSize: CGFloat = 24
    static let largeIconSize: CGFloat = 48
    static let splashIconSize: CGFloat = 80
    static let inputBarHeight: CGFloat = 44

    // MARK: - 字体等级 (映射)
    static let microFontSize: CGFloat = 10
    static let captionFontSize: CGFloat = 12
    static let subheadlineFontSize: CGFloat = 14
    static let bodyFontSize: CGFloat = 16
    static let headlineFontSize: CGFloat = 18
    static let titleFontSize: CGFloat = 24

    static let titleFont: Font = .headline
    static let bodyFont: Font = .body
    static let secondaryFont: Font = .subheadline
    static let captionFont: Font = .caption

    // MARK: - 标题等级映射 (消除魔鬼数字)
    enum HeadingLevel: Int, CaseIterable {
        case h1 = 1, h2, h3, h4, h5, h6

        var size: CGFloat {
            switch self {
            case .h1: return 28
            case .h2: return 24
            case .h3: return 20
            case .h4: return 18
            case .h5: return 16
            case .h6: return 14
            }
        }

        var weight: Font.Weight {
            switch self {
            case .h1, .h2: return .bold
            case .h3, .h4, .h5: return .semibold
            case .h6: return .medium
            }
        }
        
        var topPadding: CGFloat {
            switch self {
            case .h1: return 24
            case .h2: return 20
            case .h3: return 16
            default: return 12
            }
        }
    }

    // MARK: - 图谱物理约束
    struct Graph {
        static let minScale: CGFloat = 0.5
        static let maxScale: CGFloat = 4.0
        static let defaultNodeSize: CGFloat = 24
        static let selectedNodeSize: CGFloat = 40
        static let physicsStableDuration: Double = 3.0
    }

    // MARK: - 标注颜色与容器规范
    /// 统一的容器背景色 (基于图谱 2D 柔和材质规范)
    static let containerBackground: Color = Color.wikiCard.opacity(0.6)
    /// 统一的容器边框色 (采用 2D 图谱工具栏样式的细边框)
    static let containerBorder: Color = Color.wikiBorder.opacity(0.5)
    /// 统一的边框线宽
    static let borderWidth: CGFloat = 0.5
}

// MARK: - UI 扩展助手
extension View {
    /// 应用知识管理系统统一的容器样式
    /// 包含标准的背景色、圆角、边框及阴影
    /// - Parameters:
    ///   - cornerRadius: 自定义圆角，默认为 WikiUI.cardRadius (12)
    ///   - background: 自定义背景色，默认为 WikiUI.containerBackground
    ///   - border: 自定义边框色，默认为 WikiUI.containerBorder
    ///   - padding: 是否应用内边距，默认为 true
    func wikiContainer(
        cornerRadius: CGFloat = WikiUI.cardRadius,
        background: Color = WikiUI.containerBackground,
        border: Color = WikiUI.containerBorder,
        padding: Bool = true
    ) -> some View {
        self.padding(padding ? WikiUI.standardPadding : 0)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border, lineWidth: WikiUI.borderWidth)
            )
    }
}

// MARK: - 交互样式
/// 交互反馈缩放按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
