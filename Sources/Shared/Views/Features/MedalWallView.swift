import SwiftUI

/// 奖章墙视图：展示用户已获得和待挑战的成就
struct MedalWallView: View {
    @Environment(KMStore.self) var store
    @StateObject private var medalService = MedalService.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 顶部统计
                HStack(spacing: 20) {
                    statBox(title: Localized.tr("medal.totalEarned"), value: "\(medalService.earnedMedalIDs.count)", icon: "trophy.fill", color: .orange)
                    statBox(title: Localized.tr("medal.progress"), value: "\(Int(Double(medalService.earnedMedalIDs.count) / 7.0 * 100))%", icon: "chart.bar.fill", color: .blue)
                }
                .padding(.horizontal)
                
                // 分类展示
                medalSection(title: Localized.tr("medal.category.explore"), category: .explore)
                medalSection(title: Localized.tr("medal.category.accumulation"), category: .accumulation)
                medalSection(title: Localized.tr("medal.category.connection"), category: .connection)
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("medal.wall.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    private func medalSection(title: String, category: MedalService.Medal.Category) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(getMedals(for: category)) { medal in
                    MedalCard(medal: medal, isEarned: medalService.earnedMedalIDs.contains(medal.id))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getMedals(for category: MedalService.Medal.Category) -> [MedalService.Medal] {
        // 这里的 medals 列表应与 MedalService 中的一致，或者直接从 MedalService 获取
        // 为了简化，这里先手动列出（实际生产中应由服务暴露列表）
        MedalService.shared.allMedals.filter { $0.category == category }
    }
    
    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// 需要在 MedalService 中添加 allMedals 暴露
extension MedalService {
    var allMedals: [Medal] {
        return [
            Medal(id: "first_page", titleKey: "medal.first_page.title", descKey: "medal.first_page.desc", icon: "sparkles", colorHex: "#FFD700", threshold: 1, category: .explore),
            Medal(id: "nodes_5", titleKey: "medal.nodes_5.title", descKey: "medal.nodes_5.desc", icon: "doc.badge.plus", colorHex: "#4FACFE", threshold: 5, category: .accumulation),
            Medal(id: "nodes_10", titleKey: "medal.nodes_10.title", descKey: "medal.nodes_10.desc", icon: "books.vertical.fill", colorHex: "#00F2FE", threshold: 10, category: .accumulation),
            Medal(id: "nodes_100", titleKey: "medal.nodes_100.title", descKey: "medal.nodes_100.desc", icon: "archivebox.fill", colorHex: "#A8EDEA", threshold: 100, category: .accumulation),
            Medal(id: "links_5", titleKey: "medal.links_5.title", descKey: "medal.links_5.desc", icon: "link", colorHex: "#F093FB", threshold: 5, category: .connection),
            Medal(id: "links_10", titleKey: "medal.links_10.title", descKey: "medal.links_10.desc", icon: "link.badge.plus", colorHex: "#F5576C", threshold: 10, category: .connection),
            Medal(id: "links_100", titleKey: "medal.links_100.title", descKey: "medal.links_100.desc", icon: "hubball.fill", colorHex: "#8EC5FC", threshold: 100, category: .connection)
        ]
    }
}
