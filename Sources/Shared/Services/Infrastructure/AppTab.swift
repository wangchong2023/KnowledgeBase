// AppTab.swift
//
// 作者: Wang Chong
// 功能说明: 应用程序主 Tab 定义
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 应用程序主 Tab 定义
enum AppTab: String, CaseIterable {
    case wiki
    case ingest
    case search
    case graph
    case settings
    
    var displayTitle: String {
        switch self {
        case .wiki: return Localized.tr("tab.wiki")
        case .graph: return Localized.tr("tab.graph")
        case .search: return Localized.tr("tab.search")
        case .ingest: return Localized.tr("tab.ingest")
        case .settings: return Localized.tr("tab.settings")
        }
    }
    
    var icon: String {
        switch self {
        case .wiki: return "books.vertical.fill"
        case .graph: return "circle.hexagongrid.fill"
        case .search: return "magnifyingglass"
        case .ingest: return "tray.and.arrow.down.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
