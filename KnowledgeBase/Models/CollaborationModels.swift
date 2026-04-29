import Foundation
import MultipeerConnectivity

// MARK: - Collaboration Models
struct CollabUser: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let deviceName: String
    let joinedAt: Date

    var displayLabel: String { "\(displayName) (\(deviceName))" }
}

struct CollabEdit: Identifiable, Codable {
    let id: String
    let userID: String
    let pageID: UUID
    let field: String
    let oldValue: String
    let newValue: String
    let timestamp: Date
}

enum CollabRole: String, Codable {
    case owner
    case editor
    case viewer

    var displayName: String {
        switch self {
        case .owner: return L.tr("collab.role.owner")
        case .editor: return L.tr("collab.role.editor")
        case .viewer: return L.tr("collab.role.viewer")
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .editor: return "pencil.circle.fill"
        case .viewer: return "eye.fill"
        }
    }
}

// MARK: - Discovered Room Model
struct DiscoveredRoom: Identifiable, Hashable {
    let id: String
    let peerID: MCPeerID
    let roomName: String
    let owner: String
}
