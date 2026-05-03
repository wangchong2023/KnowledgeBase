import SwiftUI
import Combine

/// 奖章系统服务：负责追踪用户成就并触发奖励弹窗
@MainActor
final class MedalService: ObservableObject {
    static let shared = MedalService()
    
    struct Medal: Identifiable, Codable, Equatable {
        let id: String
        let titleKey: String
        let descKey: String
        let icon: String
        let colorHex: String
        let threshold: Int
        let category: Category
        
        enum Category: String, Codable {
            case accumulation // 知识积累 (节点数)
            case connection   // 知识链接 (链接数)
            case explore      // 探索 (首次行为)
        }
    }
    
    @Published var newlyEarnedMedal: Medal?
    @Published var earnedMedalIDs: Set<String> = []
    
    private let medals: [Medal] = [
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
    }
    
    /// 检查并触发成就
    func checkAchievements(nodeCount: Int, linkCount: Int) {
        for medal in medals {
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
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
