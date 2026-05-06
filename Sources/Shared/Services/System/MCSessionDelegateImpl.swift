// MCSessionDelegateImpl.swift
//
// 作者: Wang Chong
// 功能说明: Extracted from CollaborationService to reduce class size and improve testability.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
@preconcurrency import MultipeerConnectivity

// MARK: - MCSession Delegate Implementation
/// Extracted from CollaborationService to reduce class size and improve testability.
final class MCSessionDelegateImpl: NSObject, MCSessionDelegate {
    private let onPeerConnected: (MCPeerID) -> Void
    private let onPeerDisconnected: (MCPeerID) -> Void
    private let onDataReceived: (Data, MCPeerID) -> Void
    private let onStatusChange: (MCSessionState, MCPeerID) -> Void

    init(
        onPeerConnected: @escaping (MCPeerID) -> Void,
        onPeerDisconnected: @escaping (MCPeerID) -> Void,
        onDataReceived: @escaping (Data, MCPeerID) -> Void,
        onStatusChange: @escaping (MCSessionState, MCPeerID) -> Void
    ) {
        self.onPeerConnected = onPeerConnected
        self.onPeerDisconnected = onPeerDisconnected
        self.onDataReceived = onDataReceived
        self.onStatusChange = onStatusChange
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange newState: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch newState {
            case .connected:
                self.onPeerConnected(peerID)
            case .notConnected:
                self.onPeerDisconnected(peerID)
            case .connecting:
                self.onStatusChange(newState, peerID)
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.onDataReceived(data, peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiser Delegate Implementation
final class MCAdvertiserDelegateImpl: NSObject, MCNearbyServiceAdvertiserDelegate {
    private let onInvitation: (MCPeerID, Data?, @escaping (Bool, MCSession?) -> Void) -> Void
    private let onError: (Error) -> Void

    init(
        onInvitation: @escaping (MCPeerID, Data?, @escaping (Bool, MCSession?) -> Void) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onInvitation = onInvitation
        self.onError = onError
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        onInvitation(peerID, context, invitationHandler)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onError(error)
        }
    }
}

// MARK: - MCNearbyServiceBrowser Delegate Implementation
final class MCBrowserDelegateImpl: NSObject, MCNearbyServiceBrowserDelegate {
    private let onRoomFound: (MCPeerID, [String: String]?) -> Void
    private let onRoomLost: (MCPeerID) -> Void
    private let onError: (Error) -> Void

    init(
        onRoomFound: @escaping (MCPeerID, [String: String]?) -> Void,
        onRoomLost: @escaping (MCPeerID) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onRoomFound = onRoomFound
        self.onRoomLost = onRoomLost
        self.onError = onError
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            self?.onRoomFound(peerID, info)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.onRoomLost(peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onError(error)
        }
    }
}


extension MCSessionDelegateImpl: @unchecked Sendable {}
extension MCAdvertiserDelegateImpl: @unchecked Sendable {}
extension MCBrowserDelegateImpl: @unchecked Sendable {}
