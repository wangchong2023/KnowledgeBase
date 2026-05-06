// TooltipManager.swift
//
// 作者: Wang Chong
// 功能说明: 管理引导提示的显示状态，支持首次使用检测。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

/// 管理引导提示的显示状态，支持首次使用检测。
@MainActor
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

    var pendingTooltips: [TooltipType] {
        TooltipType.allCases.filter { !isShown($0) }
    }
}
