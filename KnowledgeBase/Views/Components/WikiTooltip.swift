import SwiftUI

// MARK: - Wiki Tooltip
/// 引导提示组件，用于首次使用时的操作引导。
struct WikiTooltip: View {
    let title: String
    let description: String
    let icon: String
    var arrowDirection: ArrowDirection = .top
    var accentColor: Color = .wikiAccent

    enum ArrowDirection {
        case top, bottom, left, right
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.wikiText)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: WikiUI.medium)
                .fill(Color.wikiCard)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        )
        .overlay(
            arrowView,
            alignment: arrowAlignment
        )
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.medium))
    }

    @ViewBuilder
    private var arrowView: some View {
        switch arrowDirection {
        case .top:
            VStack(spacing: 0) {
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 12, height: 8)
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: -1)
                Spacer()
            }
        case .bottom:
            VStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 12, height: 8)
                    .rotationEffect(.degrees(180))
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            }
        case .left:
            HStack(spacing: 0) {
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(-90))
                Spacer()
            }
        case .right:
            HStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.wikiCard)
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(90))
            }
        }
    }

    private var arrowAlignment: Alignment {
        switch arrowDirection {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tooltip Overlay Manager
/// 管理引导提示的显示状态，支持首次使用检测。
class TooltipManager: ObservableObject {
    static let shared = TooltipManager()

    @Published var activeTooltip: TooltipType?
    @Published var shownTooltips: Set<String> = []

    private let defaults = UserDefaults.standard
    private let shownKey = "km_shown_tooltips"

    enum TooltipType: String, CaseIterable {
        case createPage = "create_page"
        case wikiLink = "wiki_link"
        case graphFilter = "graph_filter"
        case ingest = "ingest"
        case chat = "chat"
        case tag = "tag"

        var titleKey: String {
            switch self {
            case .createPage: return "tooltip.createPage.title"
            case .wikiLink: return "tooltip.wikiLink.title"
            case .graphFilter: return "tooltip.graphFilter.title"
            case .ingest: return "tooltip.ingest.title"
            case .chat: return "tooltip.chat.title"
            case .tag: return "tooltip.tag.title"
            }
        }

        var descriptionKey: String {
            switch self {
            case .createPage: return "tooltip.createPage.desc"
            case .wikiLink: return "tooltip.wikiLink.desc"
            case .graphFilter: return "tooltip.graphFilter.desc"
            case .ingest: return "tooltip.ingest.desc"
            case .chat: return "tooltip.chat.desc"
            case .tag: return "tooltip.tag.desc"
            }
        }

        var icon: String {
            switch self {
            case .createPage: return "plus.circle.fill"
            case .wikiLink: return "link"
            case .graphFilter: return "line.3.horizontal.decrease.circle"
            case .ingest: return "tray.and.arrow.down.fill"
            case .chat: return "brain.head.profile"
            case .tag: return "tag.fill"
            }
        }
    }

    private init() {
        shownTooltips = Set(defaults.stringArray(forKey: shownKey) ?? [])
    }

    func markShown(_ tooltip: TooltipType) {
        shownTooltips.insert(tooltip.rawValue)
        defaults.set(Array(shownTooltips), forKey: shownKey)
    }

    func isShown(_ tooltip: TooltipType) -> Bool {
        shownTooltips.contains(tooltip.rawValue)
    }

    func resetAll() {
        shownTooltips.removeAll()
        defaults.removeObject(forKey: shownKey)
    }

    /// 返回所有未展示过的 tooltip（按顺序）
    var pendingTooltips: [TooltipType] {
        TooltipType.allCases.filter { !isShown($0) }
    }
}

// MARK: - View Extension
extension View {
    /// 在视图上叠加一个引导提示浮层
    func tooltip(_ type: TooltipManager.TooltipType, isPresented: Binding<Bool>) -> some View {
        self.overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                WikiTooltip(
                    title: Localized.tr(type.titleKey),
                    description: Localized.tr(type.descriptionKey),
                    icon: type.icon,
                    arrowDirection: .top,
                    accentColor: .wikiAccent
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented.wrappedValue = false
                        TooltipManager.shared.markShown(type)
                    }
                }
            }
        }
    }
}
