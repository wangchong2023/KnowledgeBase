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
    @Published var connectionError: String? = nil
    @Published var isConnecting: Bool = false

    /// KMStore reference for applying remote page changes
    weak var store: KMStore?

    private let maxRecentEdits = 100
    private let serviceType = "km-collab"

    // MARK: - Constants
    /// Timeout for peer invitation response (seconds)
    private static let inviteTimeout: TimeInterval = 30
    /// Connection attempt timeout
    private static let connectionTimeout: TimeInterval = 15

    // MC objects — only initialized on real devices
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Delegates
    private var sessionDelegate: MCSessionDelegateImpl?
    private var advertiserDelegate: MCAdvertiserDelegateImpl?
    private var browserDelegate: MCBrowserDelegateImpl?

    // Connection tracking
    private var connectionTimer: Timer?
    private var pendingInvitations: [MCPeerID] = []

    private let deviceName = UIDevice.current.name
    private var userName: String {
        UserDefaults.standard.string(forKey: "km_username") ?? deviceName
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

    /// Inject KMStore for applying remote page changes
    func setStore(_ store: KMStore) {
        self.store = store
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

        clearConnectionTimer()
        self.roomName = roomName
        self.role = .owner
        connectionError = nil
        isConnecting = true

        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID

        setupSession(peerID: peerID)
        setupAdvertiser(peerID: peerID, roomName: roomName)

        isHosting = true
        isJoined = true
        startConnectionTimer()
        statusMessage = Localized.tr("collab.status.hosting")
    }

    // MARK: - Join Session
    func startBrowsing() {
        guard !isSimulator else { return }

        clearConnectionTimer()
        connectionError = nil
        isConnecting = true

        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID

        setupSession(peerID: peerID)
        setupBrowser(peerID: peerID)

        statusMessage = Localized.tr("collab.status.searching")
    }

    func joinRoom(_ room: DiscoveredRoom) {
        guard !isSimulator, let session = session, let browser = browser else { return }
        browser.invitePeer(room.peerID, to: session, withContext: nil, timeout: Self.inviteTimeout)
        pendingInvitations.append(room.peerID)
        self.role = .editor
        isConnecting = true
        startConnectionTimer()
        statusMessage = Localized.tr("collab.status.joining")
    }

    // MARK: - Stop
    func stop() {
        clearConnectionTimer()
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil

        isHosting = false
        isJoined = false
        isConnecting = false
        connectedPeers.removeAll()
        discoveredRooms.removeAll()
        recentEdits.removeAll()
        pendingInvitations.removeAll()
        connectionError = nil

        #if !targetEnvironment(simulator)
        statusMessage = Localized.tr("collab.status.disconnected")
        #else
        statusMessage = Localized.tr("collab.status.simulatorNotSupported")
        #endif
    }

    // MARK: - Connection Timer
    private func startConnectionTimer() {
        clearConnectionTimer()
        DispatchQueue.main.async { [weak self] in
            self?.connectionTimer = Timer.scheduledTimer(withTimeInterval: Self.connectionTimeout, repeats: false) { [weak self] _ in
                self?.handleConnectionTimeout()
            }
        }
    }

    private func clearConnectionTimer() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }

    private func handleConnectionTimeout() {
        isConnecting = false
        if connectedPeers.isEmpty {
            connectionError = Localized.tr("collab.error.connectionTimeout")
            statusMessage = Localized.tr("collab.status.disconnected")
        }
    }

    // MARK: - Permission Check
    /// Returns true if current role allows editing/broadcasting
    private var canEdit: Bool {
        role == .owner || role == .editor
    }

    // MARK: - Broadcast Edit
    func broadcastEdit(pageID: UUID, field: String, oldValue: String, newValue: String) {
        guard !isSimulator else { return }
        guard canEdit else {
            statusMessage = Localized.tr("collab.error.noPermission")
            return
        }

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
        guard canEdit else {
            statusMessage = Localized.tr("collab.error.noPermission")
            return
        }

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
        UserDefaults.standard.set(name, forKey: "km_username")
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
        clearConnectionTimer()
        isConnecting = false
        connectionError = nil

        let user = CollabUser(
            id: peerID.displayName,
            displayName: peerID.displayName.components(separatedBy: "|").first ?? peerID.displayName,
            deviceName: "",
            joinedAt: Date()
        )
        if !connectedPeers.contains(where: { $0.id == user.id }) {
            connectedPeers.append(user)
        }
        pendingInvitations.removeAll { $0 == peerID }
        isJoined = true
        statusMessage = Localized.tr("collab.status.connected")
    }

    private func handlePeerDisconnected(_ peerID: MCPeerID) {
        connectedPeers.removeAll { $0.id == peerID.displayName }
        pendingInvitations.removeAll { $0 == peerID }
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
           payload["type"] as? String == "pageSync",
           let pageData = payload["page"] as? [String: Any] {
            applyRemotePage(pageData)
            return
        }
    }

    // MARK: - Remote Page Sync
    /// Apply a remote page update with last-write-wins conflict resolution
    private func applyRemotePage(_ pageData: [String: Any]) {
        guard let idString = pageData["id"] as? String,
              let pageID = UUID(uuidString: idString),
              let title = pageData["title"] as? String,
              let content = pageData["content"] as? String,
              let typeRaw = pageData["type"] as? String,
              let pageType = PageType(rawValue: typeRaw),
              let tags = pageData["tags"] as? [String],
              let statusRaw = pageData["status"] as? String,
              let status = PageStatus(rawValue: statusRaw),
              let updatedTs = pageData["updated"] as? TimeInterval
        else { return }

        let remoteUpdated = Date(timeIntervalSince1970: updatedTs)
        // handleDataReceived is already called on main thread via MCSessionDelegateImpl
        // so we can directly update the store without additional dispatch
        guard let store = store else { return }

        // Last-write-wins conflict resolution
        if let existingPage = store.pages.first(where: { $0.id == pageID }) {
            if remoteUpdated > existingPage.updated {
                var updated = existingPage
                updated.title = title
                updated.content = content
                updated.type = pageType
                updated.tags = tags
                updated.status = status
                updated.updated = remoteUpdated
                store.updatePage(updated, forceDeepScan: false)
                statusMessage = Localized.tr("collab.status.pageReceived")
            }
        } else {
            // New page from remote — create it
            let newPage = WikiPage(
                id: pageID,
                title: title,
                type: pageType,
                content: content,
                aliases: [],
                tags: tags,
                status: status,
                confidence: .medium,
                sources: [],
                relatedPageIDs: [],
                isPinned: false,
                contentHash: nil,
                created: remoteUpdated,
                updated: remoteUpdated
            )
            store.insertRemotePage(newPage)
            statusMessage = Localized.tr("collab.status.pageReceived")
        }
    }
}
