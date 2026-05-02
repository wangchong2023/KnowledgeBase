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
            .navigationTitle(Localized.tr("collab.hostSession"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerIcon: some View {
        Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.system(size: 48))
            .foregroundStyle(.wikiAccent)
    }
    
    private var titleText: some View {
        Text(Localized.tr("collab.hostSetup"))
            .font(.headline)
            .foregroundStyle(.wikiText)
    }
    
    private var roomNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("collab.roomName"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            TextField(Localized.tr("collab.roomNamePlaceholder"), text: $roomName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("hosting-room-name-field")
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Localized.tr("collab.howItWorks"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            CollabInfoRow(icon: "wifi", text: Localized.tr("collab.info.local"))
            CollabInfoRow(icon: "lock.shield.fill", text: Localized.tr("collab.info.encrypted"))
            CollabInfoRow(icon: "person.2.fill", text: Localized.tr("collab.info.maxPeers"))
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    private var startButton: some View {
        Button(action: {
            let name = roomName.isEmpty ? Localized.tr("collab.room") : roomName
            collabService.startHosting(roomName: name)
            dismiss()
        }) {
            Text(Localized.tr("collab.startHosting"))
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