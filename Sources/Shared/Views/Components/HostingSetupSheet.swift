// HostingSetupSheet.swift
//
// 作者: Wang Chong
// 功能说明: struct HostingSetupSheet
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Hosting Setup Sheet
/// 协作托管设置面板组件
/// 负责在发起 P2P 协作会话前配置房间名称、展示安全提示及启动服务监听
struct HostingSetupSheet: View {
    @ObservedObject var collabService: CollaborationService
    @Binding var roomName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerIcon
                    titleText
                    roomNameField
                    infoSection
                    startButton
                }
                .padding()
            }
            .background(Color.wikiBackground)
            .navigationTitle(L10n.Collaboration.tr("hostSession"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
    
    private var headerIcon: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 48))
            .foregroundStyle(.wikiAccent)
    }
    
    private var titleText: some View {
        Text(L10n.Collaboration.tr("hostSetup"))
            .font(.headline)
            .foregroundStyle(.wikiText)
    }
    
    private var roomNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Collaboration.tr("roomName"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            TextField(L10n.Collaboration.tr("roomNamePlaceholder"), text: $roomName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("hosting-room-name-field")
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Collaboration.tr("howItWorks"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            CollabInfoRow(icon: "wifi", text: L10n.Collaboration.tr("info.local"))
            CollabInfoRow(icon: "lock.shield.fill", text: L10n.Collaboration.tr("info.encrypted"))
            CollabInfoRow(icon: "person.2.fill", text: L10n.Collaboration.tr("info.maxPeers"))
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    private var startButton: some View {
        Button(action: {
            let name = roomName.isEmpty ? L10n.Collaboration.tr("room") : roomName
            collabService.startHosting(roomName: name)
            dismiss()
        }) {
            Text(L10n.Collaboration.tr("startHosting"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.wikiAccent)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
        .accessibilityIdentifier("hosting-start-button")
    }
}