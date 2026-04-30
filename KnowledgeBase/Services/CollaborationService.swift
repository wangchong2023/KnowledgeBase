import Foundation
import Combine
import MultipeerConnectivity

// MARK: - Collaboration Service
/// Real-time multi-user collaboration via MultipeerConnectivity (local Wi-Fi/Bluetooth).
/// NOTE: MultipeerConnectivity causes EXC_GUARD (XPC_MISUSE_FAULT) crash on the iOS Simulator.
/// Real MC networking is only activated on physical devices.
final class CollaborationService: NSObject, ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var isHosting: Bool = false
    @Published var isJoined: Bool = false
    @Published var connectedPeers: [CollabUser] = []
    @Published var role: CollabRole = .owner
    @Published var roomName: String = ""
    @Published var recentEdits: [CollabEdit] = []
    @Published var statusMessage: String = ""
    @Published var discoveredRooms: [DiscoveredRoom] = []
    @Published var isSimulator: Bool = false

    private let maxRecentEdits = 100
    private let serviceType = "wikicraft-collab"
    
    // MARK: - Constants
    /// Timeout for peer invitation response (seconds)
    private static let inviteTimeout: TimeInterval = 30

    // MC objects — only initialized on real devices
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Delegates
    private var sessionDelegate: MCSessionDelegateImpl?
    private var advertiserDelegate: MCAdvertiserDelegateImpl?
    private var browserDelegate: MCBrowserDelegateImpl?

    private let deviceName = UIDevice.current.name
    private var userName: String {
        UserDefaults.standard.string(forKey: "wikicraft_username") ?? deviceName
    }

    // MARK: - Init
    override init() {
        #if targetEnvironment(simulator)
        isSimulator = true
        #endif
        super.init()
        checkAvailability()
    }

    deinit {
        stop()
    }

    // MARK: - Availability
    private func checkAvailability() {
        #if targetEnvironment(simulator)
        isAvailable = false
        statusMessage = Localized.tr("collab.status.simulatorNotSupported")
        #else
        isAvailable = true
        statusMessage = Localized.tr("collab.status.ready")
        #endif
    }

    // MARK: - Host Session
    func startHosting(roomName: String) {
        guard !isSimulator else { return }

        self.roomName = roomName
        self.role = .owner

        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID

        setupSession(peerID: peerID)
        setupAdvertiser(peerID: peerID, roomName: roomName)

        isHosting = true
        isJoined = true
        statusMessage = Localized.tr("collab.status.hosting")
    }

    // MARK: - Join Session
    func startBrowsing() {
        guard !isSimulator else { return }

        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID

        setupSession(peerID: peerID)
        setupBrowser(peerID: peerID)

        statusMessage = Localized.tr("collab.status.searching")
    }

    func joinRoom(_ room: DiscoveredRoom) {
        guard !isSimulator, let session = session, let browser = browser else { return }
        browser.invitePeer(room.peerID, to: session, withContext: nil, timeout: Self.inviteTimeout)
        self.role = .editor
        statusMessage = Localized.tr("collab.status.joining")
    }

    // MARK: - Stop
    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil

        isHosting = false
        isJoined = false
        connectedPeers.removeAll()
        discoveredRooms.removeAll()
        recentEdits.removeAll()

        #if !targetEnvironment(simulator)
        statusMessage = Localized.tr("collab.status.disconnected")
        #else
        statusMessage = Localized.tr("collab.status.simulatorNotSupported")
        #endif
    }

    // MARK: - Broadcast Edit
    func broadcastEdit(pageID: UUID, field: String, oldValue: String, newValue: String) {
        guard !isSimulator else { return }

        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: myPeerID?.displayName ?? "unknown",
            pageID: pageID,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            timestamp: Date()
        )
        appendEdit(edit)
        if let data = try? JSONEncoder().encode(edit) {
            send(data: data)
        }
    }

    // MARK: - Broadcast Full Page
    func broadcastPage(_ page: WikiPage) {
        guard !isSimulator, let session = session, !session.connectedPeers.isEmpty else { return }

        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": page.id.uuidString,
                "title": page.title,
                "content": page.content,
                "type": page.type.rawValue,
                "tags": page.tags,
                "status": page.status.rawValue,
                "updated": page.updated.timeIntervalSince1970
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            send(data: data)
        }
    }

    // MARK: - Set Username
    func setUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "wikicraft_username")
    }

    // MARK: - Private Helpers
    private func send(data: Data) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func appendEdit(_ edit: CollabEdit) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentEdits.append(edit)
            if self.recentEdits.count > self.maxRecentEdits {
                self.recentEdits.removeFirst(self.recentEdits.count - self.maxRecentEdits)
            }
        }
    }

    // MARK: - Session Setup
    private func setupSession(peerID: MCPeerID) {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        sessionDelegate = MCSessionDelegateImpl(
            onPeerConnected: { [weak self] peerID in self?.handlePeerConnected(peerID) },
            onPeerDisconnected: { [weak self] peerID in self?.handlePeerDisconnected(peerID) },
            onDataReceived: { [weak self] data, peerID in self?.handleDataReceived(data, from: peerID) },
            onStatusChange: { [weak self] state, peerID in self?.handleSessionStatusChange(state, peerID: peerID) }
        )
        session.delegate = sessionDelegate
        self.session = session
    }

    private func setupAdvertiser(peerID: MCPeerID, roomName: String) {
        advertiserDelegate = MCAdvertiserDelegateImpl(
            onInvitation: { [weak self] _, _, handler in
                handler(true, self?.session)
            },
            onError: { [weak self] error in
                self?.statusMessage = "\(Localized.tr("collab.status.advertiseError")): \(error.localizedDescription)"
            }
        )
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: [
            "room": roomName,
            "owner": userName
        ], serviceType: serviceType)
        advertiser?.delegate = advertiserDelegate
        advertiser?.startAdvertisingPeer()
    }

    private func setupBrowser(peerID: MCPeerID) {
        browserDelegate = MCBrowserDelegateImpl(
            onRoomFound: { [weak self] peerID, info in
                guard let self = self else { return }
                let roomName = info?["room"] ?? Localized.tr("collab.defaultRoom")
                let owner = info?["owner"] ?? peerID.displayName
                let id = peerID.displayName
                if !self.discoveredRooms.contains(where: { $0.id == id }) {
                    self.discoveredRooms.append(DiscoveredRoom(id: id, peerID: peerID, roomName: roomName, owner: owner))
                }
            },
            onRoomLost: { [weak self] peerID in
                self?.discoveredRooms.removeAll { $0.id == peerID.displayName }
            },
            onError: { [weak self] error in
                self?.statusMessage = "\(Localized.tr("collab.status.browseError")): \(error.localizedDescription)"
            }
        )
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = browserDelegate
        browser?.startBrowsingForPeers()
    }

    // MARK: - Session Event Handlers
    private func handlePeerConnected(_ peerID: MCPeerID) {
        let user = CollabUser(
            id: peerID.displayName,
            displayName: peerID.displayName.components(separatedBy: "|").first ?? peerID.displayName,
            deviceName: "",
            joinedAt: Date()
        )
        if !connectedPeers.contains(where: { $0.id == user.id }) {
            connectedPeers.append(user)
        }
        isJoined = true
        statusMessage = Localized.tr("collab.status.connected")
    }

    private func handlePeerDisconnected(_ peerID: MCPeerID) {
        connectedPeers.removeAll { $0.id == peerID.displayName }
        if connectedPeers.isEmpty && !isHosting {
            isJoined = false
            statusMessage = Localized.tr("collab.status.disconnected")
        }
    }

    private func handleSessionStatusChange(_ state: MCSessionState, peerID: MCPeerID) {
        if state == .connecting {
            statusMessage = Localized.tr("collab.status.connecting")
        }
    }

    private func handleDataReceived(_ data: Data, from peerID: MCPeerID) {
        // Try to decode as CollabEdit
        if let edit = try? JSONDecoder().decode(CollabEdit.self, from: data) {
            appendEdit(edit)
            return
        }
        // Try to decode as page sync
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           payload["type"] as? String == "pageSync" {
            statusMessage = Localized.tr("collab.status.pageReceived")
        }
    }
}
