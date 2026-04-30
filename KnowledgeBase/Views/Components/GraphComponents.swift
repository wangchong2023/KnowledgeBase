import SwiftUI

// MARK: - Graph Node View
/// 图谱中的单个节点渲染。
struct GraphNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isAnimating: Bool
    let linkCount: Int
    let onSelect: () -> Void

    private var nodeSize: CGFloat {
        isSelected ? 40 : max(24, min(40, 20 + CGFloat(linkCount) * 3))
    }

    var body: some View {
        ZStack {
            // 选中时的脉冲
            if isSelected {
                Circle()
                    .fill(node.type.themedColor.opacity(0.15))
                    .frame(width: nodeSize + 20, height: nodeSize + 20)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            }

            // 发光
            if isSelected {
                Circle()
                    .fill(node.type.themedColor.opacity(0.3))
                    .frame(width: nodeSize + 12, height: nodeSize + 12)
                    .blur(radius: 4)
            }

            // 节点圆
            Circle()
                .fill(
                    LinearGradient(
                        colors: [node.type.themedColor.opacity(0.8), node.type.themedColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: nodeSize, height: nodeSize)
                .shadow(color: node.type.themedColor.opacity(isSelected ? 0.6 : 0.3), radius: isSelected ? 10 : 4)

            // 类型图标
            Image(systemName: node.type.icon)
                .font(.system(size: isSelected ? 14 : max(9, min(14, 8 + CGFloat(linkCount)))))
                .foregroundStyle(.white)
        }
        .position(node.position)
        .onTapGesture { onSelect() }
    }
}

// MARK: - Graph Node Label
/// 节点标题标签。
struct GraphNodeLabel: View {
    let node: GraphNode
    let isSelected: Bool
    let nodeSize: CGFloat

    var body: some View {
        Text(node.title)
            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? .wikiText : .wikiSecondary)
            .lineLimit(1)
            .position(x: node.position.x, y: node.position.y + nodeSize / 2 + 12)
    }
}

// MARK: - Graph Zoom Controls
/// 缩放控制栏。
struct GraphZoomControls: View {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let onRelayout: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation { scale = max(0.5, scale - 0.2) }
                lastScale = scale
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("zoom-out")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation { scale = min(3.0, scale + 0.2) }
                lastScale = scale
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("zoom-in")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("reset")

            Divider().frame(width: 1, height: 24).background(Color.wikiBorder)

            Button(action: {
                withAnimation(.spring(response: 0.6)) { onRelayout() }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body)
                    .foregroundStyle(.wikiSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.wikiCard)
            }
            .accessibilityIdentifier("relayout")
        }
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Graph Legend
/// 图谱图例。
struct GraphLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PageType.allCases) { type in
                HStack(spacing: 6) {
                    Circle()
                        .fill(type.themedColor)
                        .frame(width: 10, height: 10)
                    Text(type.displayName)
                        .font(.caption2)
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                .stroke(Color.wikiBorder.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

// MARK: - Graph Selected Node Card
/// 选中节点的详情卡片。
struct GraphSelectedNodeCard: View {
    let page: WikiPage

    var body: some View {
        NavigationLink(destination: PageDetailView(page: page)) {
            HStack(spacing: 12) {
                Image(systemName: page.displayIcon)
                    .foregroundStyle(page.type.themedColor)
                    .frame(width: 36, height: 36)
                    .background(page.type.themedColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)
                    Text("\(page.type.displayName) · \(page.wordCount) \(L.tr("page.wordCountUnit")) · \(page.outgoingLinks.count) \(L.tr("page.outLinkUnit"))")
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.wikiSecondary)
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.mediumRadius))
            .shadow(color: .black.opacity(0.3), radius: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
