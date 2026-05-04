// MedalService.swift
//
// 作者: Wang Chong
// 功能说明: 奖章系统服务：负责追踪用户成就并触发奖励弹窗
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-03
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import Combine

/// 奖章系统服务：负责追踪用户成就并触发奖励弹窗
@MainActor
final class MedalService: ObservableObject {
    static let shared = MedalService()

    private var cancellables: Set<AnyCancellable> = []

    struct Medal: Identifiable, Codable, Equatable {
        let id: String
        let titleKey: String
        let descKey: String
        let icon: String
        let colorHex: String
        let threshold: Int
        let category: Category
        
        enum Category: String, Codable {
            case accumulation = "accumulation" // 知识积累 (节点数)
            case connection = "connection"     // 知识链接 (链接数)
            case explore = "explore"           // 探索 (首次行为)
        }
    }
    
    @Published var newlyEarnedMedal: Medal?
    @Published var earnedMedalIDs: Set<String> = []
    
    let allMedals: [Medal] = [
        // 1. 探索奖章
        Medal(id: "first_page", titleKey: "medal.first_page.title", descKey: "medal.first_page.desc", icon: "sparkles", colorHex: "#FFD700", threshold: 1, category: .explore),
        
        // 2. 积累奖章 (节点数)
        Medal(id: "nodes_5", titleKey: "medal.nodes_5.title", descKey: "medal.nodes_5.desc", icon: "doc.badge.plus", colorHex: "#4FACFE", threshold: 5, category: .accumulation),
        Medal(id: "nodes_10", titleKey: "medal.nodes_10.title", descKey: "medal.nodes_10.desc", icon: "books.vertical.fill", colorHex: "#00F2FE", threshold: 10, category: .accumulation),
        Medal(id: "nodes_100", titleKey: "medal.nodes_100.title", descKey: "medal.nodes_100.desc", icon: "archivebox.fill", colorHex: "#A8EDEA", threshold: 100, category: .accumulation),
        
        // 3. 连接奖章 (链接数)
        Medal(id: "links_5", titleKey: "medal.links_5.title", descKey: "medal.links_5.desc", icon: "link", colorHex: "#F093FB", threshold: 5, category: .connection),
        Medal(id: "links_10", titleKey: "medal.links_10.title", descKey: "medal.links_10.desc", icon: "link.badge.plus", colorHex: "#F5576C", threshold: 10, category: .connection),
        Medal(id: "links_100", titleKey: "medal.links_100.title", descKey: "medal.links_100.desc", icon: "hubball.fill", colorHex: "#8EC5FC", threshold: 100, category: .connection)
    ]
    
    private init() {
        loadEarnedMedals()
        observeEvents()
    }

    /// 通过 WikiEventBus 自动监听页面变更，解耦对 KMStore 的直接依赖
    private func observeEvents() {
        WikiEventBus.shared.subscribe()
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .pageCreated(_, _, let nodeCount, let linkCount),
                     .pageUpdated(_, let nodeCount, let linkCount):
                    self.checkAchievements(nodeCount: nodeCount, linkCount: linkCount)
                case .pagesCleared:
                    self.reset()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    /// 检查并触发成就
    func checkAchievements(nodeCount: Int, linkCount: Int) {
        for medal in allMedals {
            if earnedMedalIDs.contains(medal.id) { continue }
            
            var isEarned = false
            switch medal.category {
            case .explore where medal.id == "first_page":
                isEarned = nodeCount >= 1
            case .accumulation:
                isEarned = nodeCount >= medal.threshold
            case .connection:
                isEarned = linkCount >= medal.threshold
            default:
                break
            }
            
            if isEarned {
                markAsEarned(medal)
            }
        }
    }
    
    private func markAsEarned(_ medal: Medal) {
        earnedMedalIDs.insert(medal.id)
        newlyEarnedMedal = medal
        saveEarnedMedals()
        HapticManager.shared.trigger(.success)
    }
    
    private func saveEarnedMedals() {
        if let data = try? JSONEncoder().encode(earnedMedalIDs) {
            UserDefaults.standard.set(data, forKey: "earned_medals")
        }
    }
    
    private func loadEarnedMedals() {
        if let data = UserDefaults.standard.data(forKey: "earned_medals"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            earnedMedalIDs = decoded
        }
    }
    
    /// 重置所有勋章数据 (Platinum Experience Item #6)
    func reset() {
        earnedMedalIDs.removeAll()
        newlyEarnedMedal = nil
        UserDefaults.standard.removeObject(forKey: "earned_medals")
    }
}
