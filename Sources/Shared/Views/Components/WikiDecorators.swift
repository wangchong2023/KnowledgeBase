// WikiDecorators.swift
//
// 作者: Wang Chong
// 功能说明: 提供一种跨视图层级触发导航的方式，绕过对单一全局 Path 的硬编码依赖。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Navigation Action
/// 提供一种跨视图层级触发导航的方式，绕过对单一全局 Path 的硬编码依赖。
/// 语义化导航操作闭包封装
/// 负责在组件间安全地传递导航指令，绕过 SwiftUI 默认的强耦合路径绑定
struct NavigateAction: Sendable {
    private let action: @Sendable (WikiPage) -> Void
    
    init(action: @escaping @Sendable (WikiPage) -> Void) {
        self.action = action
    }
    
    func callAsFunction(_ page: WikiPage) {
        action(page)
    }
}

struct NavigateActionKey: EnvironmentKey {
    static let defaultValue = NavigateAction(action: { _ in })
}

extension EnvironmentValues {
    var navigate: NavigateAction {
        get { self[NavigateActionKey.self] }
        set { self[NavigateActionKey.self] = newValue }
    }
}

// MARK: - Wiki Decorators
/// 装饰性元素组件库：增强视觉质感、层次感、科技感

// MARK: - Glass Card
/// 玻璃质感卡片：带磨砂玻璃背景 + 柔和阴影
/// 磨砂玻璃质感卡片容器
/// 负责为内容提供半透明、多层深度的背景及发光边框，提升界面的空间感与现代感
struct WikiGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = WikiUI.medium
    var isHighlighted: Bool = false

    init(
        cornerRadius: CGFloat = WikiUI.medium,
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(WikiUI.cardPadding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.wikiCard.opacity(0.6))
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.wikiAccent.opacity(0.3), lineWidth: 1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(isHighlighted ? 0.15 : 0.08), radius: isHighlighted ? 12 : 8, x: 0, y: isHighlighted ? 6 : 4)
    }
}

// MARK: - Shimmer Loading
/// 闪烁加载动画效果
/// 扫光特效动画视图
/// 负责生成流动的线性渐变遮罩，常用于骨架屏或内容加载中的视觉占位
struct WikiShimmer: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.wikiAccent.opacity(0.15),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: phase)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 400
            }
        }
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.2),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = geometry.size.width * 1.6
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmerWiki() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Glow Effect
/// 发光效果装饰
/// 发光图标装饰组件
/// 负责为图标添加多层扩散的颜色晕染效果，用于强调重要操作或系统提示
struct WikiGlow: View {
    let icon: String
    var color: Color = .wikiAccent
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: 8)

            // 内层光晕
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: 4)

            // 中心图标
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Section Divider with Icon
/// 带图标的分隔线
/// 语义化分隔线组件
/// 负责在内容区块间插入带有可选图标与标题的视觉分割，支持自定义描边颜色
struct WikiDivider: View {
    var icon: String? = nil
    var title: String? = nil
    var color: Color = .wikiBorder

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            if let title = title {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary)
            }
            Rectangle()
                .fill(color)
                .frame(height: 1)
        }
    }
}

// MARK: - Accent Line
/// 左侧强调色线条装饰
/// 侧边强调线条装饰
/// 负责在文本或区块左侧插入一条固定宽度的颜色条，常用于引用、警示或关键信息标注
struct WikiAccentLine: View {
    var color: Color = .wikiAccent
    var width: CGFloat = 3

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.tiny))
    }
}

// MARK: - Badge
/// 小徽章/角标
/// 通用角标/徽章组件
/// 负责在右上角或行内展示数字、状态文字，支持胶囊型与圆形两种形态
struct WikiBadge: View {
    let text: String
    var color: Color = .wikiAccent
    var isPill: Bool = true

    var body: some View {
        Group {
            if isPill {
                Text(text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Text(text)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(color)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Gradient Background Layer
/// 背景渐变装饰层
/// 渐变背景装饰层
/// 负责生成通用的线性渐变背景，通常作为页面或卡片的视觉底层，增强色彩层次
struct WikiGradientBG: View {
    var colors: [Color] = [.wikiAccent.opacity(0.08), .clear]
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// MARK: - Dot Pattern Background
/// 点阵背景装饰
/// 科技感点阵背景装饰
/// 负责在容器背景中绘制半透明的规律点阵，常用于 3D 图谱或数据实验室的背景装饰
struct WikiDotPattern: View {
    var dotColor: Color = .wikiBorder
    var spacing: CGFloat = 20
    var dotSize: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(dotColor.opacity(0.4))
                    )
                }
            }
        }
    }
}

// MARK: - Card Decoration
/// 卡片顶部装饰条
/// 卡片顶部强调装饰条
/// 负责在卡片最上方插入极细的颜色条，用于区分不同类别的知识卡片
struct WikiCardAccent: View {
    var color: Color = .wikiAccent
    var height: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: WikiUI.tiny)
            .fill(color)
            .frame(height: height)
    }
}

// MARK: - Icon Box
/// 图标背景框
/// 品牌图标背景框
/// 负责在标准化的圆角矩形背景中渲染图标，具备自动配色与尺寸适配逻辑
struct WikiIconBox: View {
    let icon: String
    var color: Color = .wikiAccent
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WikiUI.small)
                .fill(color.opacity(0.12))

            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Skeleton Loader
/// 骨架屏占位
/// 骨架屏内容占位符
/// 负责在数据加载期间展示带有扫光动画的条状块，模拟真实内容布局，减少用户感知焦虑
struct WikiSkeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = WikiUI.tiny

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.wikiSecondary.opacity(0.15))
            .frame(height: height)
            .shimmerWiki()
    }
}

// MARK: - Pulse Indicator
/// 脉冲指示点
/// 脉冲状态指示点
/// 负责展示一个带有向外扩散波纹动画的小圆点，常用于表示“在线”、“正在录音”或“后台处理中”
struct WikiPulseDot: View {
    var color: Color = .wikiAccent
    var size: CGFloat = 8

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0 : 1)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Quiz Presentation Modifier
struct QuizPresentationModifier: ViewModifier {
    @Binding var activeQuiz: QuizModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .sheet(item: $activeQuiz) { quiz in
                    QuizView(quiz: quiz)
                        .frame(minWidth: 500, minHeight: 600)
                }
        } else {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            content
                .fullScreenCover(item: $activeQuiz) { quiz in
                    QuizView(quiz: quiz)
                }
            #else
            content
                .sheet(item: $activeQuiz) { quiz in
                    QuizView(quiz: quiz)
                }
            #endif
        }
    }
}

extension View {
    func quizPresentation(activeQuiz: Binding<QuizModel?>) -> some View {
        modifier(QuizPresentationModifier(activeQuiz: activeQuiz))
    }
}
