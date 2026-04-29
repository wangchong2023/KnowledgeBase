import SwiftUI

// MARK: - Wiki Empty State
/// 通用空状态组件，统一各页面的空数据展示。
/// - Parameters:
///   - icon: SF Symbol 图标名
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
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.wikiSecondary)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.wikiText)

            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
            }

            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.wikiAccent.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.wikiAccent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
            }

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
                    .background(actionBackgroundColor(for: action.role))
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    private func actionForegroundColor(for role: Action.Role?) -> Color {
        switch role {
        case .primary, .none:
            Color.white
        case .secondary:
            Color.wikiAccent
        case .destructive:
            Color.red
        }
    }

    private func actionBackgroundColor(for role: Action.Role?) -> Color {
        switch role {
        case .primary, .none:
            Color.wikiAccent
        case .secondary:
            Color.wikiAccent.opacity(0.1)
        case .destructive:
            Color.red.opacity(0.1)
        }
    }

    private func buildAccessibilityLabel() -> String {
        var label = "\(title)。"
        if let description = description {
            label += " \(description)。"
        }
        if let hint = hint {
            label += " 提示：\(hint)"
        }
        if action != nil {
            label += " 可执行操作。"
        }
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
