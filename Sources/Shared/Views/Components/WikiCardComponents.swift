import SwiftUI

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            // 带发光效果的图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.wikiText)

            Text(title)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Quick Action Row
struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 渐变图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: WikiUI.small)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiSecondary.opacity(0.6))
            }
            .padding(14)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
            .shadow(color: .black.opacity(isPressed ? 0.04 : 0.08), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

// MARK: - Guide Step Row
struct GuideStepRow: View {
    let number: Int
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            // 带数字序号的渐变圆
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.wikiAccent, .wikiAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: .wikiAccent.opacity(0.3), radius: 4, x: 0, y: 2)

                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.wikiText)

            Spacer()
        }
    }
}

// MARK: - Page Row View
struct PageRowView: View {
    let page: WikiPage
    var compact: Bool = false
    @Environment(KMStore.self) var store
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: page.displayIcon)
                .font(.body)
                .foregroundStyle(page.type.themedColor)
                .frame(width: 32, height: 32)
                .background(page.type.themedColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                    .lineLimit(1)
                
                if !compact {
                    HStack(spacing: 8) {
                        Text(page.type.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(page.type.themedColor.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundStyle(page.type.themedColor)
                        
                        Text(page.updated, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.wikiSecondary)
                        
                        if !page.tags.isEmpty {
                            Text(page.tags.prefix(2).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.wikiSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(Color.fromModelColorName(page.status.colorName))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
        .contentShape(Rectangle()) // 确保整行可点
    }
}
