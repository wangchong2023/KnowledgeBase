import Foundation
import Speech
import AVFoundation

// MARK: - Speech Service
/// Speech-to-text service using Apple's Speech framework.
/// Supports real-time transcription and audio file transcription.
final class SpeechService: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var audioLevel: Float = 0
    /// 最近 20 个音频级别采样，用于波形可视化
    @Published var audioLevelHistory: [Float] = Array(repeating: 0, count: 20)
    @Published var statusMessage: String = ""
    @Published var supportedLanguages: [(code: String, name: String)] = []
    @Published var selectedLanguage: String = "zh-CN"
    @Published var hasPermission: Bool = false
    @Published var recordings: [VoiceRecording] = []
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // MARK: - Init
    init() {
        loadSupportedLanguages()
        checkPermission()
        loadRecordings()
    }
    
    // MARK: - Permission
    func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.hasPermission = status == .authorized
                switch status {
                case .authorized:
                    self.statusMessage = L.tr("speech.status.ready")
                case .denied:
                    self.statusMessage = L.tr("speech.status.denied")
                case .restricted:
                    self.statusMessage = L.tr("speech.status.restricted")
                case .notDetermined:
                    self.statusMessage = L.tr("speech.status.notDetermined")
                @unknown default:
                    self.statusMessage = L.tr("speech.status.unknown")
                }
            }
        }
    }
    
    // MARK: - Languages
    private func loadSupportedLanguages() {
        let locales: [(String, String)] = [
            ("zh-CN", L.tr("speech.lang.zhHans")),
            ("zh-TW", L.tr("speech.lang.zhHant")),
            ("en-US", L.tr("speech.lang.enUS")),
            ("en-GB", L.tr("speech.lang.enGB")),
            ("ja-JP", L.tr("speech.lang.jaJP")),
            ("ko-KR", L.tr("speech.lang.koKR")),
            ("fr-FR", L.tr("speech.lang.frFR")),
            ("de-DE", L.tr("speech.lang.deDE")),
            ("es-ES", L.tr("speech.lang.esES")),
            ("pt-BR", L.tr("speech.lang.ptBR")),
        ]
        
        supportedLanguages = locales.filter { locale in
            SFSpeechRecognizer(locale: Locale(identifier: locale.0)) != nil
        }
        
        // Auto-select based on system language
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") {
            selectedLanguage = "zh-CN"
        } else if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") {
            selectedLanguage = "zh-TW"
        } else if let match = supportedLanguages.first(where: { preferred.hasPrefix($0.code) }) {
            selectedLanguage = match.code
        }
    }
    
    // MARK: - Start Recording
    func startRecording() {
        guard hasPermission else {
            statusMessage = L.tr("speech.status.denied")
            return
        }
        
        let locale = Locale(identifier: selectedLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            statusMessage = L.tr("speech.status.localeNotSupported")
            return
        }
        
        speechRecognizer = recognizer
        
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        
        let inputNode = audioEngine.inputNode
        
        #if targetEnvironment(simulator)
        statusMessage = L.tr("speech.status.simulatorNotSupported")
        return
        #else
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Install audio tap for level monitoring
        // Use nil format to let the system choose the optimal format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level
            let channelData = buffer.floatChannelData?[0]
            let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
            let avgPower = 20 * log10(max(rms, 1e-8))
            
            DispatchQueue.main.async {
                self?.audioLevel = max(0, min(1, (avgPower + 50) / 50))
                self?.audioLevelHistory.removeFirst()
                self?.audioLevelHistory.append(max(0, min(1, (avgPower + 50) / 50)))
            }
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            statusMessage = L.tr("speech.status.recording")
        } catch {
            statusMessage = L.tr("speech.status.audioError")
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.stopRecording()
                    }
                }
                
                if let error = error {
                    self?.statusMessage = "\(L.tr("speech.status.error")): \(error.localizedDescription)"
                    self?.stopRecording()
                }
            }
        }
        #endif
    }
    
    // MARK: - Stop Recording
    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isRecording = false
        audioLevel = 0
        audioLevelHistory = Array(repeating: 0, count: 20)
        
        if !transcribedText.isEmpty {
            statusMessage = L.tr("speech.status.complete")
        } else {
            statusMessage = L.tr("speech.status.ready")
        }
    }
    
    // MARK: - Transcribe Audio File
    func transcribeFile(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }
        
        let locale = Locale(identifier: selectedLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechError.localeNotSupported
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    // MARK: - Save Recording
    func saveRecording(title: String) -> VoiceRecording {
        let recording = VoiceRecording(
            id: UUID(),
            title: title,
            text: transcribedText,
            language: selectedLanguage,
            duration: 0, // Would need timer for real duration
            createdAt: Date()
        )
        recordings.insert(recording, at: 0)
        saveRecordingsToDisk()
        return recording
    }
    
    func deleteRecording(_ recording: VoiceRecording) {
        recordings.removeAll { $0.id == recording.id }
        saveRecordingsToDisk()
    }
    
    // MARK: - Clear
    func clearTranscription() {
        transcribedText = ""
        statusMessage = L.tr("speech.status.ready")
    }
    
    // MARK: - Persistence
    private let recordingsKey = "wikicraft_voice_recordings"
    
    private func loadRecordings() {
        if let data = UserDefaults.standard.data(forKey: recordingsKey),
           let decoded = try? JSONDecoder().decode([VoiceRecording].self, from: data) {
            recordings = decoded
        }
    }
    
    private func saveRecordingsToDisk() {
        if let data = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(data, forKey: recordingsKey)
        }
    }
}

// MARK: - Voice Recording Model
struct VoiceRecording: Identifiable, Codable {
    let id: UUID
    let title: String
    let text: String
    let language: String
    let duration: TimeInterval
    let createdAt: Date
}

// MARK: - Speech Error
enum SpeechError: LocalizedError {
    case localeNotSupported
    case notAuthorized
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .localeNotSupported: return L.tr("speech.error.localeNotSupported")
        case .notAuthorized: return L.tr("speech.error.notAuthorized")
        case .audioEngineError: return L.tr("speech.error.audioEngine")
        }
    }
}
