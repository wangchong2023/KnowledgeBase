// SettingsAboutView.swift
//
// 作者: Wang Chong
// 功能说明: struct SettingsAboutView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

struct SettingsAboutView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "books.vertical.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.wikiSource, .wikiAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Localized.tr("app.name"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.wikiText)
                        Text(Localized.tr("welcome.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.wikiSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                InfoRow(icon: "tag", text: L10n.Settings.version + ": " + appVersion)
                InfoRow(icon: "hammer", text: L10n.Settings.tr("build") + ": " + buildNumber)
                InfoRow(icon: "desktopcomputer", text: L10n.Settings.tr("platform") + ": " + platformName)
            } header: {
                Text(L10n.Settings.tr("section.about"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Settings.tr("aboutDescription"))
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("app.name"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var platformName: String {
        #if targetEnvironment(macCatalyst)
        return "macOS (Catalyst)"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(iOS)
        // 运行时区分 iPad（iPadOS）与 iPhone（iOS）
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPadOS"
        }
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Unknown"
        #endif
    }
}