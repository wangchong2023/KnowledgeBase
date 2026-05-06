// MedalWallView.swift
//
// 作者: Wang Chong
// 功能说明: 奖章墙视图：展示用户已获得和待挑战的成就
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI

// MARK: - 勋章墙
/// 奖章墙视图
/// 负责展示用户的知识成就体系、勋章获得情况及成长里程碑进度
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
        medalService.allMedals.filter { $0.category == category }
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
