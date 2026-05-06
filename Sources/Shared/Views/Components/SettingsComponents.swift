// SettingsComponents.swift
//
// 作者: Wang Chong
// 功能说明: 设置页导航行，支持可选副标题和尾部视图。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - Settings Navigation Row
/// 设置页导航行，支持可选副标题和尾部视图。
/// 设置页通用导航行组件
/// 负责在列表样式中展示功能图标、标题、副标题，并提供标准化的导航跳转能力
struct SettingsNavigationRow<Destination: View, Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let identifier: String?
    let destination: Destination
    let trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        identifier: String? = nil,
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.identifier = identifier
        self.destination = destination()
        self.trailing = trailing()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .foregroundStyle(.wikiText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                trailing
            }
        }
        .accessibilityIdentifier(identifier ?? title)
    }
}

/// 便利初始化（无尾部视图）
extension SettingsNavigationRow where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        identifier: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.identifier = identifier
        self.destination = destination()
        self.trailing = EmptyView()
    }
}

// MARK: - Settings Stat Row
/// 设置页统计行：标签 + 值。
/// 设置页统计数据展示行组件
/// 负责在设置界面以简洁的键值对形式展示系统统计信息（如存储占用、页面总数等）
struct SettingsStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.wikiText)
            Spacer()
            Text(value)
                .foregroundStyle(.wikiSecondary)
        }
    }
}

// MARK: - Info Row
/// 信息提示行（图标 + 文字）。
/// 基础信息提示行组件
/// 负责以图标加文字的形式展示辅助信息或状态提示，通常用于说明页面功能
struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
            Spacer()
        }
    }
}

