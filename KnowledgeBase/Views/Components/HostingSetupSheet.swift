import SwiftUI

// MARK: - Hosting Setup Sheet
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
            .navigationTitle(L.tr("collab.hostSession"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("misc.cancel")) { dismiss() }
                }
            }
        }
    }
    
    private var headerIcon: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 48))
            .foregroundStyle(.wikiAccent)
    }
    
    private var titleText: some View {
        Text(L.tr("collab.hostSetup"))
            .font(.headline)
            .foregroundStyle(.wikiText)
    }
    
    private var roomNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.tr("collab.roomName"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            TextField(L.tr("collab.roomNamePlaceholder"), text: $roomName)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.tr("collab.howItWorks"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            CollabInfoRow(icon: "wifi", text: L.tr("collab.info.local"))
            CollabInfoRow(icon: "lock.shield.fill", text: L.tr("collab.info.encrypted"))
            CollabInfoRow(icon: "person.2.fill", text: L.tr("collab.info.maxPeers"))
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    private var startButton: some View {
        Button(action: {
            let name = roomName.isEmpty ? "知识库 Room" : roomName
            collabService.startHosting(roomName: name)
            dismiss()
        }) {
            Text(L.tr("collab.startHosting"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.wikiAccent)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
    }
}