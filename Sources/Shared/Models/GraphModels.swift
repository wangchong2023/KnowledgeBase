import Foundation

// MARK: - Log Entry
struct LogEntry: Identifiable, Codable {
    var id: UUID
    var action: LogAction
    var target: String
    var details: String
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        action: LogAction,
        target: String,
        details: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
        self.timestamp = timestamp
    }
}

// MARK: - Graph Node
struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    let type: PageType
    var position: CGPoint
    var isHighlighted: Bool = false
    var communityID: Int? = nil
    var communityCohesion: Double? = nil
}

// MARK: - Graph Edge
struct GraphEdge: Identifiable {
    let id = UUID()
    let source: UUID
    let target: UUID
}
