import SwiftUI

// MARK: - Save Voice Note Sheet
struct SaveVoiceNoteSheet: View {
    @ObservedObject var speechService: SpeechService
    @Binding var title: String
    @EnvironmentObject var store: KMStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: PageType = .source
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    titleField
                    typePicker
                    previewSection
                    saveButton
                }
                .padding()
            }
            .background(Color.wikiBackground)
            .navigationTitle(L.tr("speech.saveTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.tr("misc.cancel")) { dismiss() }
                }
            }
        }
    }
    
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.tr("speech.noteTitle"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            TextField(L.tr("speech.noteTitlePlaceholder"), text: $title)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.tr("ocr.pageType"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            Picker("", selection: $selectedType) {
                ForEach(PageType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.tr("pdf.contentPreview"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            Text(speechService.transcribedText)
                .font(.body)
                .foregroundStyle(.wikiText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(8)
                .padding(12)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        }
    }
    
    private var saveButton: some View {
        Button(action: saveNote) {
            Text(L.tr("speech.saveToWiki"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.wikiAccent)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
        }
    }
    
    private func saveNote() {
        let noteTitle = title.isEmpty
            ? "\(L.tr("speech.voiceNote")) \(Date().formatted(.dateTime.month().day().hour().minute()))"
            : title
        _ = store.createPage(
            title: noteTitle,
            type: selectedType,
            content: speechService.transcribedText,
            tags: [L.tr("speech.voiceTag")]
        )
        
        let _ = speechService.saveRecording(title: noteTitle)
        speechService.clearTranscription()
        title = ""
        dismiss()
    }
}

// MARK: - Voice Recording Row
struct VoiceRecordingRow: View {
    let recording: VoiceRecording
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.wikiSource)
                .frame(width: 32, height: 32)
                .background(Color.wikiSource.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                    .lineLimit(1)
                Text(String(recording.text.prefix(50)))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(recording.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
        .frame(maxWidth: .infinity)
    }
}