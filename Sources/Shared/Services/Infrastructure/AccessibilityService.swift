import Combine
import UIKit

// MARK: - Accessibility Service
/// Provides accessibility enhancements, VoiceOver support, and dynamic type scaling.
@MainActor
final class AccessibilityService: ObservableObject {
    /// 替代 SwiftUI ContentSizeCategory 的本地缩放级别枚举
    enum ScalingSizeCategory: String, CaseIterable, Sendable {
        case extraSmall, small, medium, large, extraLarge
        case extraExtraLarge, extraExtraExtraLarge
        case accessibilityMedium, accessibilityLarge, accessibilityExtraLarge
        case accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge

        fileprivate var multiplier: CGFloat {
            switch self {
            case .extraSmall: 0.82
            case .small: 0.88
            case .medium: 0.95
            case .large: 1.0
            case .extraLarge: 1.12
            case .extraExtraLarge: 1.23
            case .extraExtraExtraLarge: 1.35
            case .accessibilityMedium: 1.5
            case .accessibilityLarge: 1.65
            case .accessibilityExtraLarge: 1.8
            case .accessibilityExtraExtraLarge: 2.0
            case .accessibilityExtraExtraExtraLarge: 2.2
            }
        }
    }

    @Published var preferredContentSizeCategory: ScalingSizeCategory = .large
    @Published var isVoiceOverRunning: Bool = false
    @Published var isReduceMotionEnabled: Bool = false
    @Published var isHighContrastEnabled: Bool = false

    // MARK: - Dynamic Type Scaling
    func scaledFont(base: CGFloat, category: ScalingSizeCategory) -> CGFloat {
        base * category.multiplier
    }

    // MARK: - Animation Control
    var shouldAnimate: Bool {
        !isReduceMotionEnabled
    }

    // MARK: - VoiceOver Helpers
    static func pageAnnouncement(_ page: WikiPage) -> String {
        var parts: [String] = []
        parts.append(page.title)
        parts.append(page.type.displayName)
        parts.append(page.status.displayName)
        if !page.tags.isEmpty {
            parts.append(Localized.tr("a11y.tags") + ": " + page.tags.joined(separator: ", "))
        }
        let wordStr = "\(page.wordCount) " + Localized.tr("a11y.words")
        parts.append(wordStr)
        return parts.joined(separator: ", ")
    }

    static func graphNodeAnnouncement(_ node: GraphNode, linkCount: Int) -> String {
        "\(node.title), \(node.type.displayName), \(linkCount) " + Localized.tr("a11y.links")
    }

    // MARK: - Haptic Feedback
    static func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func playNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
