// CollaborationModels.swift
//
// 作者: Wang Chong
// 功能说明: struct CollabUser
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

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
    case owner = "owner"
    case editor = "editor"
    case viewer = "viewer"

    var displayName: String {
        switch self {
        case .owner: return L10n.Collaboration.tr("role.owner")
        case .editor: return L10n.Collaboration.tr("role.editor")
        case .viewer: return L10n.Collaboration.tr("role.viewer")
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
