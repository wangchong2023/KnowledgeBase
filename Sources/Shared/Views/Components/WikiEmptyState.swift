// WikiEmptyState.swift
//
// 作者: Wang Chong
// 功能说明: 通用空状态组件，统一各页面的空数据展示。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Wiki Empty State
/// 通用空状态组件，统一各页面的空数据展示。
/// - Parameters:
///   - icon: SF Symbol 主图标名
///   - title: 主标题
///   - description: 可选描述文本
///   - hint: 可选提示（通常是高亮小字）
///   - action: 可选操作按钮配置
struct WikiEmptyState: View {
    let icon: String
    let title: String
    let description: String?
    let hint: String?
    let action: Action?

    /// 操作按钮配置
    struct Action {
        let label: String
        let icon: String?
        let role: Role?
        let handler: () -> Void

        enum Role { case primary, secondary, destructive }

        init(label: String, icon: String? = nil, role: Action.Role = .secondary, handler: @escaping () -> Void) {
            self.label = label
            self.icon = icon
            self.role = role
            self.handler = handler
        }
    }

    init(
        icon: String,
        title: String,
        description: String? = nil,
        hint: String? = nil,
        action: Action? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.hint = hint
        self.action = action
    }

    var body: some View {
        VStack(spacing: 24) {
            // 视觉区：图标 + 装饰卡片
            ZStack {
                // 背景装饰圆
                Circle()
                    .fill(Color.wikiAccent.opacity(0.07))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.wikiAccent.opacity(0.04))
                    .frame(width: 160, height: 160)

                // 主图标
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiAccent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(height: 100)

            // 文字区
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.wikiText)

                if let description = description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // 提示区
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.wikiAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: WikiUI.chipRadius)
                            .fill(Color.wikiAccent.opacity(0.1))
                    )
            }

            // 操作按钮
            if let action = action {
                Button(action: action.handler) {
                    HStack(spacing: 6) {
                        if let icon = action.icon {
                            Image(systemName: icon)
                        }
                        Text(action.label)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(actionForegroundColor(for: action.role))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        action.role == .primary || action.role == nil
                            ? Color.wikiAccent
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: WikiUI.small)
                            .stroke(action.role == .primary || action.role == nil ? Color.clear : Color.wikiAccent, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func actionForegroundColor(for role: Action.Role?) -> Color {
        switch role {
        case .primary, .none: return .white
        case .secondary: return .wikiAccent
        case .destructive: return .red
        }
    }

    private func buildAccessibilityLabel() -> String {
        var label = "\(title)。"
        if let description = description { label += " \(description)。" }
        if let hint = hint { label += " \(L10n.Common.Empty.tr("hint"))：\(hint)" }
        if action != nil { label += " \(L10n.Common.Empty.tr("actionHint"))。" }
        return label
    }
}

// MARK: - Convenience Initializers
extension WikiEmptyState {
    /// 图标 + 标题 + 描述（无操作）
    static func simple(icon: String, title: String, description: String? = nil) -> WikiEmptyState {
        WikiEmptyState(icon: icon, title: title, description: description)
    }

    /// 带操作按钮的空状态
    static func withAction(
        icon: String,
        title: String,
        description: String? = nil,
        hint: String? = nil,
        actionLabel: String,
        actionIcon: String? = nil,
        actionRole: Action.Role = .secondary,
        actionHandler: @escaping () -> Void
    ) -> WikiEmptyState {
        WikiEmptyState(
            icon: icon,
            title: title,
            description: description,
            hint: hint,
            action: Action(label: actionLabel, icon: actionIcon, role: actionRole, handler: actionHandler)
        )
    }
}
