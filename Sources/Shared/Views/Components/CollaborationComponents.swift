// CollaborationComponents.swift
//
// 作者: Wang Chong
// 功能说明: 协作信息提示行（图标 + 文字），轻量级复用组件。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Collab Info Row
/// 协作信息提示行（图标 + 文字），轻量级复用组件。
struct CollabInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.wikiAccent)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.wikiText)
        }
    }
}

// MARK: - Discovered Room Row
/// 发现房间列表行。
struct DiscoveredRoomRow: View {
    let room: DiscoveredRoom
    let onJoin: () -> Void

    var body: some View {
        Button(action: onJoin) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.wikiAccent)

                VStack(alignment: .leading) {
                    Text(room.roomName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.wikiText)
                    Text("\(L10n.Collaboration.tr("hostedBy")) \(room.owner)")
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.wikiAccent)
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collab-discovered-room-\(room.id)")
    }
}

// MARK: - Connected Peer Row
/// 已连接用户行。
struct ConnectedPeerRow: View {
    let peer: CollabUser
    var showRole: Bool = false
    var roleDisplayName: String? = nil

    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundStyle(.wikiAccent)
            Text(peer.displayName)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
            Spacer()
            if showRole, let roleName = roleDisplayName {
                Text(roleName)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            } else {
                Text(peer.joinedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .accessibilityIdentifier("collab-connected-peer-\(peer.id)")
    }
}

// MARK: - Recent Edit Row
/// 最近编辑记录行。
struct RecentEditRow: View {
    let edit: CollabEdit

    var body: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.wikiConcept)

            VStack(alignment: .leading, spacing: 2) {
                Text(edit.userID.components(separatedBy: "|").first ?? edit.userID)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.wikiText)
                Text("\(edit.field) → \(String(edit.newValue.prefix(50)))")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(edit.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .accessibilityIdentifier("collab-edit-row-\(edit.id)")
    }
}

// MARK: - Role Badge
/// 角色徽章（Owner/Editor/Viewer）。
struct CollabRoleBadge: View {
    let role: CollabRole
    
    private var color: Color {
        switch role {
        case .owner: return .yellow
        case .editor: return .wikiAccent
        case .viewer: return .wikiSecondary
        }
    }
    
    var body: some View {
        Text(role.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .foregroundStyle(color)
    }
}