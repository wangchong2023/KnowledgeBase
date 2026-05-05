// WikiUI.swift
//
// 作者: Wang Chong
// 功能说明: 本文件定义了知识管理系统的统一 UI 规范库（WikiUI），旨在通过集中管理的语义化常量替换全工程中的硬编码数值。
// 该规范库涵盖了从原子级视觉单位到复杂交互参数的完整定义：
// 1. 栅格系统与圆角：提供了微型（Tiny）、小型（Small）、中型（Medium）及大型（Large）四档标准化圆角与内边距，确保界面节奏的一致性。
// 2. 字体等级（Typography）：除了标准的系统字体映射外，通过 HeadingLevel 枚举规范了 Markdown 文档的标题层级关系，支持跨平台的视觉对齐。
// 3. 物理仿真参数：定义了知识图谱布局引擎所需的收敛阈值、缩放边界及力导向常数，确保图谱在大规模节点下的交互稳定性。
// 4. 颜色与特效语义：封装了渐变色位置、阴影半径及动画时长，为系统各组件提供统一的视觉反馈深度。
// 版本: 1.2
// 修改记录:
//   - 2026-05-05: 升级为全系统 UI 规范基座，完善标题枚举与物理常数
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Wiki UI Constants
/// Centralized UI design constants to replace hard-coded values across the codebase.
enum WikiUI {
    // MARK: - Layout & Radius
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

    // MARK: - Spacing & Padding
    static let standardPadding: CGFloat = 16
    static let widePadding: CGFloat = 20
    static let tightPadding: CGFloat = 8
    static let cardPadding: CGFloat = standardPadding
    static let sectionPadding: CGFloat = widePadding

    // MARK: - Animation
    static let standardAnimation: Animation = .easeInOut(duration: 0.25)
    static let quickAnimation: Animation = .easeInOut(duration: 0.15)
    static let springAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    // MARK: - Icon & Component Sizes
    static let microIconSize: CGFloat = 12
    static let captionIconSize: CGFloat = 16
    static let titleIconSize: CGFloat = 24
    static let largeIconSize: CGFloat = 48
    static let splashIconSize: CGFloat = 80
    static let inputBarHeight: CGFloat = 44

    // MARK: - Typography (Mappings)
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

    // MARK: - Graph Constraints
    struct Graph {
        static let minScale: CGFloat = 0.5
        static let maxScale: CGFloat = 4.0
        static let defaultNodeSize: CGFloat = 24
        static let selectedNodeSize: CGFloat = 40
        static let physicsStableDuration: Double = 3.0
    }
}

// MARK: - Button Styles
/// 交互反馈缩放按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
