import SwiftUI

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
            .accessibilityHint(Localized.tr("a11y.tapToOpen"))
            .accessibilityAddTraits(.isButton)
    }

    func wikiGraphNode(title: String, type: PageType, linkCount: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(type.displayName), \(linkCount) " + Localized.tr("a11y.links"))
            .accessibilityHint(Localized.tr("a11y.tapToOpen"))
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
