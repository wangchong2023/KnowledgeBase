// WatchWidgets.swift
//
// 作者: Wang Chong
// 功能说明: 定义表盘点击意图
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 手表端小组件
/// 手表端点击意图定义
/// 负责响应表盘 Complication 的点击事件，支持快速跳转至采集界面
struct CaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记录"
    static var description = IntentDescription("直接进入语音采集界面")
    
    func perform() async throws -> some IntentResult {
        // 这里的逻辑通常是由系统拉起 App 并带入特定 Context
        return .result()
    }
}

/// 智宇表盘组件
struct WatchCaptureWidget: Widget {
    let kind: String = "WatchCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WatchWidgetView(entry: entry)
        }
        .configurationDisplayName("智宇采集")
        .description("快速捕捉灵感。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct WatchWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        // 使用带有 Intent 的 Button，点击即触发 App 逻辑
        Button(intent: CaptureIntent()) {
            ZStack {
                Circle()
                    .fill(Color.wikiAccent.gradient)
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .containerBackground(Color.wikiAccent.gradient, for: .widget)
    }
}
