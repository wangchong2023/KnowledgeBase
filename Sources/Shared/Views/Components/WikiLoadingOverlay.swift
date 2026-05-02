import SwiftUI

// MARK: - Wiki Loading Overlay
/// 全屏加载遮罩，统一各页面的 Loading 状态展示。
struct WikiLoadingOverlay: View {
    /// 是否显示加载遮罩
    let isLoading: Bool
    /// 加载提示文字（可选）
    let message: String?
    /// 遮罩背景色（默认半透明黑色）
    let backgroundColor: Color
    /// 前景色（默认 accent）
    let foregroundColor: Color

    init(
        isLoading: Bool,
        message: String? = nil,
        backgroundColor: Color = Color.black.opacity(0.35),
        foregroundColor: Color = .wikiAccent
    ) {
        self.isLoading = isLoading
        self.message = message
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        if isLoading {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(message ?? Localized.tr("misc.loading"))

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(1.4)

                    if let message = message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            }
        }
    }
}

// MARK: - Loading Button Style
/// 内嵌在按钮中的 Loading 指示器修饰符。
struct LoadingButtonModifier: ViewModifier {
    let isLoading: Bool
    let loadingText: String?
    let normalText: String
    let icon: String?

    func body(content: Content) -> some View {
        content
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        if let loadingText = loadingText {
                            Text(loadingText)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                }
            }
    }
}

extension View {
    /// 在按钮内显示 Loading 状态，替代按钮文字。
    func loadingOverlay(
        isLoading: Bool,
        loadingText: String? = nil,
        normalText: String,
        icon: String? = nil
    ) -> some View {
        self.modifier(LoadingButtonModifier(
            isLoading: isLoading,
            loadingText: loadingText,
            normalText: normalText,
            icon: icon
        ))
    }
}

// MARK: - Inline Progress Row
/// 行内加载指示器（用于 List 或 HStack 中的单行加载状态）。
struct WikiInlineProgress: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.wikiAccent)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)

            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
