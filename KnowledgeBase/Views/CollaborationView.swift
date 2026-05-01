import SwiftUI
import MultipeerConnectivity

// MARK: - Collaboration View (entry point with NavigationStack)
struct CollaborationView: View {
    var body: some View {
        NavigationStack {
            CollaborationViewContent()
        }
    }
}

// MARK: - Collaboration View Content (for use inside parent NavigationStack)
struct CollaborationViewContent: View {
    @StateObject private var collabService = CollaborationService()
    @EnvironmentObject var store: KMStore
    @State private var roomName = ""
    @State private var userName = ""
    @State private var showHostingSheet = false
    @State private var showBrowsing = false
    @State private var showConnectionError = false

    private var recentEditsSnapshot: [CollabEdit] {
        Array(collabService.recentEdits.suffix(10))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if collabService.isSimulator { simulatorWarning }
                statusSection

                if !collabService.isJoined {
                    actionSection
                    if showBrowsing { discoveredRoomsSection }
                } else {
                    sessionSection
                    peersSection
                    editsSection
                }
            }
            .padding()
        }
        .background(Color.wikiBackground)
        .navigationTitle(Localized.tr("collab.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHostingSheet) {
            HostingSetupSheet(collabService: collabService, roomName: $roomName)
        }
        .alert(Localized.tr("collab.error.connectionTimeout"), isPresented: $showConnectionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(collabService.connectionError ?? "")
        }
        .onAppear {
            userName = UserDefaults.standard.string(forKey: "wikicraft_username") ?? UIDevice.current.name
            collabService.setStore(store)
        }
        .onChange(of: collabService.connectionError) { _, newValue in
            showConnectionError = (newValue != nil)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiAccent, .wikiConcept],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(Localized.tr("collab.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Simulator Warning
    private var simulatorWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text(Localized.tr("collab.simulatorWarning"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Status
    private var statusSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(collabService.isJoined ? .green : .gray)
                .frame(width: 12, height: 12)
            
            Text(collabService.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
            
            Spacer()
            
            if collabService.isJoined {
                Text("\(collabService.connectedPeers.count + 1)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.wikiAccent.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(.wikiAccent)
            }
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Actions
    private var actionSection: some View {
        VStack(spacing: 12) {
            usernameField
            hostButton
            joinButton
            if showBrowsing { stopSearchingButton }
        }
    }
    
    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("collab.username"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)

            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(.wikiAccent)
                TextField(Localized.tr("collab.usernamePlaceholder"), text: $userName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .accessibilityIdentifier("collab-username-field")
                    .onChange(of: userName) { _, newValue in
                        collabService.setUserName(newValue)
                    }
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        }
    }

    private var hostButton: some View {
        Button(action: { showHostingSheet = true }) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text(Localized.tr("collab.hostSession"))
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.wikiAccent)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
        .disabled(collabService.isSimulator)
        .opacity(collabService.isSimulator ? 0.5 : 1.0)
        .accessibilityIdentifier("collab-host-button")
    }

    private var joinButton: some View {
        Button(action: {
            showBrowsing = true
            collabService.startBrowsing()
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(Localized.tr("collab.joinSession"))
            }
            .font(.headline)
            .foregroundStyle(.wikiAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.wikiAccent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
        .disabled(collabService.isSimulator)
        .opacity(collabService.isSimulator ? 0.5 : 1.0)
        .accessibilityIdentifier("collab-join-button")
    }

    private var stopSearchingButton: some View {
        Button(action: {
            showBrowsing = false
            collabService.stop()
        }) {
            Text(Localized.tr("collab.stopSearching"))
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .accessibilityIdentifier("collab-stop-searching-button")
    }
    
    // MARK: - Discovered Rooms
    private var discoveredRoomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("collab.nearbyRooms"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            if collabService.discoveredRooms.isEmpty {
                HStack {
                    ProgressView()
                    Text(Localized.tr("collab.searching"))
                        .font(.subheadline)
                        .foregroundStyle(.wikiSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            } else {
                ForEach(collabService.discoveredRooms) { room in
                    DiscoveredRoomRow(room: room) {
                        collabService.joinRoom(room)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Info
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text(collabService.roomName)
                    .font(.headline)
                    .foregroundStyle(.wikiText)
                Spacer()
                CollabRoleBadge(role: collabService.role)
                    .accessibilityIdentifier("collab-role-badge")
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            .accessibilityIdentifier("collab-session-info")

            leaveButton
        }
    }

    private var leaveButton: some View {
        Button(action: { collabService.stop() }) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text(Localized.tr("collab.leaveSession"))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
        .accessibilityIdentifier("collab-leave-button")
    }

    // MARK: - Peers
    private var peersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("collab.connectedUsers"))
                .font(.headline)
                .foregroundStyle(.wikiText)
                .accessibilityIdentifier("collab-peers-header")

            // Self
            HStack {
                Image(systemName: "person.fill.checkmark")
                    .foregroundStyle(.green)
                Text(userName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                Spacer()
                Text(collabService.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            .accessibilityIdentifier("collab-self-peer")

            ForEach(collabService.connectedPeers) { peer in
                ConnectedPeerRow(peer: peer, showRole: false)
                    .accessibilityIdentifier("collab-peer-\(peer.id)")
            }
        }
    }
    
    // MARK: - Recent Edits
    private var editsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("collab.recentEdits"))
                .font(.headline)
                .foregroundStyle(.wikiText)
                .accessibilityIdentifier("collab-edits-header")

            if recentEditsSnapshot.isEmpty {
                Text(Localized.tr("collab.noEdits"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                    .accessibilityIdentifier("collab-no-edits")
            } else {
                ForEach(recentEditsSnapshot) { edit in
                    RecentEditRow(edit: edit)
                        .accessibilityIdentifier("collab-edit-\(edit.id)")
                }
            }
        }
    }
}