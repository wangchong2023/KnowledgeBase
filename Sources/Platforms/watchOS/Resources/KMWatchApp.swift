// KMWatchApp.swift
//
// 作者: Wang Chong
// 功能说明: Apple Watch 应用程序入口
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

/// Apple Watch 应用程序入口
@main
struct KMWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchWikiStatsView()
        }
    }
}
