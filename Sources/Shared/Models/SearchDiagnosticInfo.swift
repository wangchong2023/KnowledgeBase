import Foundation

/// 搜索诊断数据结构
struct SearchDiagnosticInfo: Identifiable, Equatable {
    let id = UUID()
    let query: String
    let rewrittenQuery: String
    let ftsCount: Int
    let vectorCount: Int
    let rrfTopResults: [ResultScore]
    
    struct ResultScore: Identifiable, Equatable {
        let id: UUID
        let title: String
        let ftsRank: Int
        let vectorRank: Int
        let finalScore: Double
    }
}
