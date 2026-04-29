import SwiftUI
import Foundation

// MARK: - Accessibility Service
/// Provides accessibility enhancements, VoiceOver support, and dynamic type scaling.
final class AccessibilityService: ObservableObject {
    @Published var preferredContentSizeCategory: ContentSizeCategory = .large
    @Published var isVoiceOverRunning: Bool = false
    @Published var isReduceMotionEnabled: Bool = false
    @Published var isHighContrastEnabled: Bool = false
    
    // MARK: - Dynamic Type Scaling
    func scaledFont(base: CGFloat, category: ContentSizeCategory) -> CGFloat {
        let multiplier: CGFloat
        switch category {
        case .extraSmall: multiplier = 0.82
        case .small: multiplier = 0.88
        case .medium: multiplier = 0.95
        case .large: multiplier = 1.0
        case .extraLarge: multiplier = 1.12
        case .extraExtraLarge: multiplier = 1.23
        case .extraExtraExtraLarge: multiplier = 1.35
        case .accessibilityMedium: multiplier = 1.5
        case .accessibilityLarge: multiplier = 1.65
        case .accessibilityExtraLarge: multiplier = 1.8
        case .accessibilityExtraExtraLarge: multiplier = 2.0
        case .accessibilityExtraExtraExtraLarge: multiplier = 2.2
        @unknown default: multiplier = 1.0
        }
        return base * multiplier
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
            parts.append(L.tr("a11y.tags") + ": " + page.tags.joined(separator: ", "))
        }
        let wordStr = "\(page.wordCount) " + L.tr("a11y.words")
        parts.append(wordStr)
        return parts.joined(separator: ", ")
    }
    
    static func graphNodeAnnouncement(_ node: GraphNode, linkCount: Int) -> String {
        "\(node.title), \(node.type.displayName), \(linkCount) " + L.tr("a11y.links")
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

// MARK: - View Extension for Accessibility
extension View {
    func wikiAccessibility(label: String, hint: String? = nil, traits: AccessibilityTraits = .isStaticText) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    func wikiPageRow(page: WikiPage) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityService.pageAnnouncement(page))
            .accessibilityHint(L.tr("a11y.tapToOpen"))
            .accessibilityAddTraits(.isButton)
    }
    
    func wikiGraphNode(title: String, type: PageType, linkCount: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(type.displayName), \(linkCount) " + L.tr("a11y.links"))
            .accessibilityHint(L.tr("a11y.tapToOpen"))
            .accessibilityAddTraits(.isButton)
    }
    
    /// Conditional animation based on Reduce Motion preference
    func wikiAnimation(_ animation: Animation = .easeInOut(duration: 0.3)) -> some View {
        self.modifier(ConditionalAnimationModifier(animation: animation))
    }
}

// MARK: - Dependency for Reduce Motion (simple wrapper)
private enum AccessibilityReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var accessibilityReduceMotion: Bool {
        get { self[AccessibilityReduceMotionKey.self] }
        set { self[AccessibilityReduceMotionKey.self] = newValue }
    }
}

// MARK: - Conditional Animation Modifier
private struct ConditionalAnimationModifier: ViewModifier {
    let animation: Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: UUID())
    }
}
