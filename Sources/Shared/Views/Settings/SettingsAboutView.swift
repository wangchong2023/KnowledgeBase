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
                InfoRow(icon: "tag", text: Localized.tr("settings.version") + ": " + appVersion)
                InfoRow(icon: "hammer", text: Localized.tr("settings.build") + ": " + buildNumber)
                InfoRow(icon: "desktopcomputer", text: Localized.tr("settings.platform") + ": " + platformName)
            } header: {
                Text(Localized.tr("settings.section.about"))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Localized.tr("settings.aboutDescription"))
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