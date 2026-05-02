import SwiftUI

// MARK: - Wiki UI Constants
/// Centralized UI design constants to replace hard-coded values across the codebase.
enum WikiUI {
    /// Corner radius — 统一为 4 档
    /// tiny: 4px   — 内联代码块、分隔线等极小元素
    /// small: 8px  — 按钮、输入框、列表项、标签
    /// medium: 12px — 通用卡片、Section
    /// large: 16px — 大型模态框
    /// chipRadius: 20px — 胶囊形标签（特殊保留）
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let chipRadius: CGFloat = 20

    // 以下为兼容别名，逐步迁移到上述 4 档
    static let cardRadius: CGFloat = medium   // 12
    static let standardRadius: CGFloat = small // 8
    static let smallRadius: CGFloat = small   // 8
    static let mediumRadius: CGFloat = medium // 12
    static let largeRadius: CGFloat = large   // 16
    static let microRadius: CGFloat = tiny    // 4
    static let tinyRadius: CGFloat = tiny     // 4
    static let inlineRadius: CGFloat = tiny   // 4
    static let hairlineRadius: CGFloat = tiny // 4
    static let sidebarRadius: CGFloat = small // 8

    /// Padding
    static let cardPadding: CGFloat = 16
    static let sectionPadding: CGFloat = 12
    static let tightPadding: CGFloat = 8

    /// Animation
    static let standardAnimation: Animation = .easeInOut(duration: 0.25)
    static let quickAnimation: Animation = .easeInOut(duration: 0.15)

    /// Icon sizes
    static let largeIconSize: CGFloat = 48
    static let titleIconSize: CGFloat = 24
    static let captionIconSize: CGFloat = 16

    // MARK: - 标准文本样式
    /// 标题样式
    static let titleFont: Font = .headline
    /// 正文样式
    static let bodyFont: Font = .body
    /// 副文本样式
    static let secondaryFont: Font = .subheadline
    /// 注释/标签样式
    static let captionFont: Font = .caption
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
