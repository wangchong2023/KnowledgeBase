// WikiCard.swift
//
// 作者: Wang Chong
// 功能说明: 应用 Wiki 卡片背景的 ViewModifier。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Wiki Card Modifier
/// 应用 Wiki 卡片背景的 ViewModifier。
/// 应用 Wiki 卡片背景的视图修饰符
/// 负责注入一致的内边距、背景色及圆角样式
struct WikiCardModifier: ViewModifier {
    var cornerRadius: CGFloat = WikiUI.cardRadius
    var padding: CGFloat = WikiUI.cardPadding
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
/// 标准 Wiki 卡片容器组件
/// 提供符合设计系统的阴影、圆角及背景封装
struct WikiCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = WikiUI.cardRadius
    var padding: CGFloat = WikiUI.cardPadding

    var body: some View {
        content
            .padding(padding)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Wiki Bordered Card
/// 带边框的卡片，用于入口卡片等需要描边的场景。
/// 带描边效果的 Wiki 卡片
/// 适用于需要视觉分割或引导点击的入口区域
struct WikiBorderedCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = WikiUI.cardRadius
    var borderColor: Color = .wikiMainBorder

    init(
        cornerRadius: CGFloat = WikiUI.cardRadius,
        borderColor: Color = .wikiMainBorder,
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
                    .stroke(borderColor, lineWidth: WikiUI.borderWidth)
            )
    }
}

// MARK: - View Extension for Card Background
extension View {
    /// 应用 Wiki 卡片背景的修饰符。
    func wikiCard(cornerRadius: CGFloat = WikiUI.cardRadius, padding: CGFloat = WikiUI.cardPadding) -> some View {
        modifier(WikiCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Wiki Section Header
/// 统一的分组标题样式。
/// 统一的章节标题组件
/// 支持左侧图标、标题文本及右侧自定义工具栏
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 12pt 升到 15pt
    private var stepFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.wikiAccent))

            Text(text)
                .font(stepFont)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 10pt 升到 12pt
    private var chipFont: Font {
        horizontalSizeClass == .regular ? .caption : .caption2
    }

    var body: some View {
        Text(text)
            .font(chipFont)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 12pt 升到 15pt
    private var chipFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(chipFont)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? color.opacity(0.25) : Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .foregroundStyle(isSelected ? color : .wikiSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: WikiUI.borderWidth)
        )
    }
}

// MARK: - Wiki Primary Button
/// 主要操作按钮，渐变背景跟随用户选择的主题色。
/// 品牌色主操作按钮
/// 支持渐变背景、加载状态及主题色自动适配
struct WikiPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var gradientColors: [Color] = [.wikiAccent, .wikiAccent.opacity(0.7)]
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 12pt 升到 15pt
    private var bannerFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(bannerFont)
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
/// 标签输入框（令牌化/芯片式输入）。
struct WikiTagField: View {
    let placeholder: String
    @Binding var tags: [String]
    @State private var newTag: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 3) {
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .medium))
                        Button(action: { 
                            withAnimation(.spring(response: 0.3)) {
                                tags.removeAll { $0 == tag }
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.wikiSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.wikiAccent.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(.wikiAccent)
                }
                
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onChange(of: newTag) { _, newValue in
                        // 自动检测空格或逗号进行分词
                        if newValue.hasSuffix(" ") || newValue.hasSuffix(",") || newValue.hasSuffix("，") {
                            addCurrentTag()
                        }
                    }
                    .onSubmit {
                        addCurrentTag()
                    }
                    .frame(minWidth: 100)
                    .foregroundStyle(.wikiText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                    .stroke(Color.wikiBorder.opacity(0.5), lineWidth: WikiUI.borderWidth)
            )
        }
    }
    
    private func addCurrentTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: ",，")))
            .replacingOccurrences(of: "#", with: "")
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation(.spring(response: 0.3)) {
                tags.append(trimmed)
            }
        }
        newTag = ""
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
