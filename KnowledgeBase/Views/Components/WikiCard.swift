import SwiftUI

// MARK: - Wiki Card Modifier
/// 应用 Wiki 卡片背景的 ViewModifier。
struct WikiCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16
    var backgroundColor: Color = .wikiCard

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Wiki Card (Container)
/// 统一的卡片容器，统一背景、圆角、内边距。
struct WikiCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16

    var body: some View {
        content
            .padding(padding)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Wiki Bordered Card
/// 带边框的卡片，用于入口卡片等需要描边的场景。
struct WikiBorderedCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12
    var borderColor: Color = .clear

    init(
        cornerRadius: CGFloat = 12,
        borderColor: Color = .clear,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - View Extension for Card Background
extension View {
    /// 应用 Wiki 卡片背景的修饰符。
    func wikiCard(cornerRadius: CGFloat = 12, padding: CGFloat = 16) -> some View {
        modifier(WikiCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Wiki Section Header
/// 统一的分组标题样式。
struct WikiSectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = .wikiSource
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.wikiText)
            Spacer()
            if let trailing = trailing {
                trailing
            }
        }
    }
}

// MARK: - Wiki Labeled Row
/// 带标签和值的行，用于设置项和信息展示。
struct WikiLabeledRow: View {
    let label: String
    let value: String
    var valueColor: Color = .wikiText

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Wiki Step Row
/// 带数字序号的步骤行。
struct WikiStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.wikiAccent))

            Text(text)
                .font(.caption)
                .foregroundStyle(.wikiText)
        }
    }
}

// MARK: - Wiki Chip / Badge
/// 胶囊形标签，用于页面类型、标签展示。
struct WikiChip: View {
    let text: String
    var color: Color = .wikiAccent
    var backgroundOpacity: Double = 0.15

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(backgroundOpacity))
            .clipShape(Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Wiki Icon Chip
/// 带图标的胶囊标签。
struct WikiIconChip: View {
    let icon: String
    let text: String
    var color: Color = .wikiAccent
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? color.opacity(0.25) : Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .foregroundStyle(isSelected ? color : .wikiSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Wiki Primary Button
/// 主要操作按钮，统一渐变背景。
struct WikiPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var gradientColors: [Color] = [.wikiSource, .wikiAccent]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Wiki Capsule Button
/// 胶囊形按钮，用于预览视图中的操作。
struct WikiCapsuleButton: View {
    let title: String
    var icon: String? = nil
    var isPrimary: Bool = true
    var color: Color = .wikiAccent

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isPrimary ? color : Color.wikiCard)
        .foregroundStyle(isPrimary ? .white : .wikiSecondary)
        .clipShape(Capsule())
    }
}

// MARK: - Wiki Success Banner
/// 成功提示横幅。
struct WikiSuccessBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
    }
}

// MARK: - Wiki Text Field
/// 统一样式的文本输入框。
struct WikiTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            .foregroundStyle(.wikiText)
    }
}

// MARK: - Wiki Tag Input Field
/// 标签输入框（带占位符提示）。
struct WikiTagField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            .foregroundStyle(.wikiText)
    }
}

// MARK: - Wiki Monospaced Text Editor
/// 等宽文本编辑器。
struct WikiMonospacedEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 200

    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .foregroundStyle(.wikiText)
            .frame(minHeight: minHeight)
            .padding(12)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
    }
}

// MARK: - Animated Section
/// 带动画的展开/收起区块。
struct AnimatedSection<Content: View>: View {
    let isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isExpanded {
            content()
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Wiki Scrollable Chips
/// 水平滚动的胶囊标签列表。
struct WikiScrollableChips<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let selectedItem: Data.Element?
    let onSelect: (Data.Element) -> Void
    var colorProvider: (Data.Element) -> Color = { _ in .wikiAccent }
    @ViewBuilder let chipContent: (Data.Element) -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items), id: \.self) { item in
                    Button(action: { onSelect(item) }) {
                        chipContent(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
