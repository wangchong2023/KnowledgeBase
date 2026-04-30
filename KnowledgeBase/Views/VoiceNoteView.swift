import SwiftUI

// MARK: - Voice Note View
struct VoiceNoteView: View {
    @StateObject private var speechService = SpeechService()
    @EnvironmentObject var store: KMStore
    @State private var noteTitle = ""
    @State private var showSaveSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                languagePicker
                recordingSection
                
                if speechService.isRecording {
                    waveformSection
                }
                
                if !speechService.transcribedText.isEmpty {
                    transcriptionSection
                }
                
                if !speechService.recordings.isEmpty {
                    recordingsSection
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.wikiBackground.ignoresSafeArea())
        .navigationTitle(Localized.tr("speech.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showSaveSheet) {
            SaveVoiceNoteSheet(speechService: speechService, title: $noteTitle)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.wikiAccent, .wikiSource],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(Localized.tr("speech.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Language Picker
    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Localized.tr("speech.language"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)
            
            Picker(Localized.tr("speech.language"), selection: $speechService.selectedLanguage) {
                ForEach(speechService.supportedLanguages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .pickerStyle(.menu)
            .tint(.wikiAccent)
        }
        .padding(14)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Recording Section
    private var recordingSection: some View {
        VStack(spacing: 14) {
            if !speechService.hasPermission {
                permissionSection
            } else {
                recordButton
                recordingStatusText
            }
        }
    }
    
    private var permissionSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.title)
                .foregroundStyle(.red)
            
            Text(Localized.tr("speech.needPermission"))
                .font(.subheadline)
                .foregroundStyle(.wikiSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { speechService.checkPermission() }) {
                Text(Localized.tr("speech.requestPermission"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.wikiAccent)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    private var recordButton: some View {
        Button(action: {
            if speechService.isRecording {
                speechService.stopRecording()
            } else {
                speechService.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.red.opacity(0.2) : Color.wikiAccent.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                if speechService.isRecording {
                    RoundedRectangle(cornerRadius: WikiUI.microRadius)
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.wikiAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var recordingStatusText: some View {
        VStack(spacing: 4) {
            Text(speechService.isRecording ? Localized.tr("speech.tapToStop") : Localized.tr("speech.tapToRecord"))
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
            
            Text(speechService.statusMessage)
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.wikiCard)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Waveform
    private var waveformSection: some View {
        VStack(spacing: 8) {
            Text(Localized.tr("speech.audioLevel"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)

            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: WikiUI.hairlineRadius)
                        .fill(Color.wikiAccent)
                        .frame(width: 5, height: max(4, CGFloat(speechService.audioLevelHistory[i]) * 40))
                }
            }
            .frame(height: 44)
        }
        .padding(14)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Transcription Result
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Localized.tr("speech.result"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                
                Spacer()
                
                Button(action: { UIPasteboard.general.string = speechService.transcribedText }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.caption)
                        .foregroundStyle(.wikiAccent)
                }
                
                Button(action: { speechService.clearTranscription() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
            }
            
            Text(speechService.transcribedText)
                .font(.body)
                .foregroundStyle(.wikiText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(10)
            
            HStack {
                Text("\(speechService.transcribedText.count) \(Localized.tr("speech.characters"))")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                
                Spacer()
                
                Button(action: { showSaveSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(Localized.tr("speech.saveToWiki"))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.wikiAccent)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Recordings History
    private var recordingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Localized.tr("speech.history"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                
                Text("\(speechService.recordings.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.wikiAccent)
                    .clipShape(Capsule())
            }
            
            VStack(spacing: 6) {
                ForEach(Array(speechService.recordings.prefix(5))) { recording in
                    VoiceRecordingRow(recording: recording)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}