import SwiftUI

// MARK: - Accent Color Picker
/// 主题色选择器，水平滚动的色圈列表。
struct AccentColorPicker: View {
    @EnvironmentObject var themeManager: ThemeManager
    let colors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主题色")
                .font(.subheadline)
                .foregroundStyle(.wikiText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(colors, id: \.self) { color in
                        let isSelected = themeManager.accentColorRaw == color
                        Button(action: { themeManager.setAccentColor(color) }) {
                            Circle()
                                .fill(Color.wikiNamed(color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(.wikiBorder, lineWidth: isSelected ? 3 : 0)
                                )
                                .overlay(
                                    Group {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("accent-color-\(color)")
                    }
                }
            }
        }
    }
}

// MARK: - Settings Navigation Row
/// 设置页导航行，支持可选副标题和尾部视图。
struct SettingsNavigationRow<Destination: View, Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let identifier: String?
    let destination: Destination
    let trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        identifier: String? = nil,
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.identifier = identifier
        self.destination = destination()
        self.trailing = trailing()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .foregroundStyle(.wikiText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                trailing
            }
        }
        .accessibilityIdentifier(identifier ?? title)
    }
}

/// 便利初始化（无尾部视图）
extension SettingsNavigationRow where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        identifier: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.identifier = identifier
        self.destination = destination()
        self.trailing = EmptyView()
    }
}

// MARK: - Settings Stat Row
/// 设置页统计行：标签 + 值。
struct SettingsStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.wikiText)
            Spacer()
            Text(value)
                .foregroundStyle(.wikiSecondary)
        }
    }
}

// MARK: - Info Row
/// 信息提示行（图标 + 文字）。
struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.wikiAccent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
            Spacer()
        }
    }
}

// MARK: - Color Extension
extension Color {
    /// 按名称获取预定义颜色。
    static func wikiNamed(_ name: String) -> Color {
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
}
