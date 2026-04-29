import SwiftUI
import MultipeerConnectivity

// MARK: - Collaboration View
struct CollaborationView: View {
    @StateObject private var collabService = CollaborationService()
    @EnvironmentObject var store: KMStore
    @State private var roomName = ""
    @State private var userName = ""
    @State private var showHostingSheet = false
    @State private var showBrowsing = false
    
    private var recentEditsSnapshot: [CollabEdit] {
        Array(collabService.recentEdits.suffix(10))
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle(L.tr("collab.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showHostingSheet) {
                HostingSetupSheet(collabService: collabService, roomName: $roomName)
            }
            .onAppear {
                userName = UserDefaults.standard.string(forKey: "wikicraft_username") ?? UIDevice.current.name
            }
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
            
            Text(L.tr("collab.subtitle"))
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
            
            Text(L.tr("collab.simulatorWarning"))
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
            Text(L.tr("collab.username"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(.wikiAccent)
                TextField(L.tr("collab.usernamePlaceholder"), text: $userName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
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
                Text(L.tr("collab.hostSession"))
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
    }
    
    private var joinButton: some View {
        Button(action: {
            showBrowsing = true
            collabService.startBrowsing()
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(L.tr("collab.joinSession"))
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
    }
    
    private var stopSearchingButton: some View {
        Button(action: {
            showBrowsing = false
            collabService.stop()
        }) {
            Text(L.tr("collab.stopSearching"))
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Discovered Rooms
    private var discoveredRoomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.tr("collab.nearbyRooms"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            if collabService.discoveredRooms.isEmpty {
                HStack {
                    ProgressView()
                    Text(L.tr("collab.searching"))
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
            }
            .padding()
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
            
            leaveButton
        }
    }
    
    private var leaveButton: some View {
        Button(action: { collabService.stop() }) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text(L.tr("collab.leaveSession"))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
    }
    
    // MARK: - Peers
    private var peersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.tr("collab.connectedUsers"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
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
            
            ForEach(collabService.connectedPeers) { peer in
                ConnectedPeerRow(peer: peer, showRole: false)
            }
        }
    }
    
    // MARK: - Recent Edits
    private var editsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.tr("collab.recentEdits"))
                .font(.headline)
                .foregroundStyle(.wikiText)
            
            if recentEditsSnapshot.isEmpty {
                Text(L.tr("collab.noEdits"))
                    .font(.subheadline)
                    .foregroundStyle(.wikiSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.wikiCard)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            } else {
                ForEach(recentEditsSnapshot) { edit in
                    RecentEditRow(edit: edit)
                }
            }
        }
    }
}