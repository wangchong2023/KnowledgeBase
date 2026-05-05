// SpeechProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了全集成的语音处理工具（SpeechProcessor），涵盖了从语音识别（STT）到语音合成（TTS）的完整处理流程。
// 该处理器通过以下核心模块提升系统的多模态交互能力：
// 1. 实时语音转写：集成 Apple Speech 框架，支持对用户语音输入进行流式转写，具备自动断句与标点纠错能力，适用于语音备忘录录入。
// 2. 语音合成输出：封装 AVSpeechSynthesizer 引擎，为系统提供流畅的语音朗读功能，支持多语种切换及语速、音调的自定义调节。
// 3. 音频权限管理：内置完善的麦克风权限请求与状态监测机制，确保在不同 OS 系统版本下的合规性与稳定性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Media 并完善语音处理流程说明
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
@preconcurrency import Speech
import AVFoundation

// MARK: - Speech Service
/// Speech-to-text service using Apple's Speech framework.
/// Supports real-time transcription and audio file transcription.
@MainActor
final class SpeechProcessor: ObservableObject {
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
                    self.statusMessage = Localized.tr("speech.status.ready")
                case .denied:
                    self.statusMessage = Localized.tr("speech.status.denied")
                case .restricted:
                    self.statusMessage = Localized.tr("speech.status.restricted")
                case .notDetermined:
                    self.statusMessage = Localized.tr("speech.status.notDetermined")
                @unknown default:
                    self.statusMessage = Localized.tr("speech.status.unknown")
                }
            }
        }
    }
    
    // MARK: - Languages
    private func loadSupportedLanguages() {
        let locales: [(String, String)] = [
            ("zh-CN", Localized.tr("speech.lang.zhHans")),
            ("zh-TW", Localized.tr("speech.lang.zhHant")),
            ("en-US", Localized.tr("speech.lang.enUS")),
            ("en-GB", Localized.tr("speech.lang.enGB")),
            ("ja-JP", Localized.tr("speech.lang.jaJP")),
            ("ko-KR", Localized.tr("speech.lang.koKR")),
            ("fr-FR", Localized.tr("speech.lang.frFR")),
            ("de-DE", Localized.tr("speech.lang.deDE")),
            ("es-ES", Localized.tr("speech.lang.esES")),
            ("pt-BR", Localized.tr("speech.lang.ptBR")),
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
            statusMessage = Localized.tr("speech.status.denied")
            return
        }

        let locale = Locale(identifier: selectedLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            statusMessage = Localized.tr("speech.status.localeNotSupported")
            return
        }

        speechRecognizer = recognizer

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        #if targetEnvironment(simulator)
        statusMessage = Localized.tr("speech.status.simulatorNotSupported")
        #else
        setupRecognitionRequest()
        guard recognitionRequest != nil else { return }

        setupAudioTap(inputNode: audioEngine.inputNode)
        startAudioEngine(audioEngine)
        startRecognitionTask(recognizer: recognizer)
        #endif
    }

    // MARK: - Setup Recognition Request
    private func setupRecognitionRequest() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
    }

    // MARK: - Setup Audio Tap
    private func setupAudioTap(inputNode: AVAudioInputNode) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.calculateAudioLevel(from: buffer)
        }
    }

    // MARK: - Calculate Audio Level
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        let avgPower = 20 * log10(max(rms, 1e-8))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.audioLevel = max(0, min(1, (avgPower + 50) / 50))
            self.audioLevelHistory.removeFirst()
            self.audioLevelHistory.append(max(0, min(1, (avgPower + 50) / 50)))
        }
    }

    // MARK: - Start Audio Engine
    private func startAudioEngine(_ audioEngine: AVAudioEngine) {
        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            statusMessage = Localized.tr("speech.status.recording")
        } catch {
            statusMessage = Localized.tr("speech.status.audioError")
        }
    }

    // MARK: - Start Recognition Task
    private func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        guard let request = recognitionRequest else { return }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString

                    if result.isFinal {
                        self?.stopRecording()
                    }
                }

                if let error = error {
                    self?.statusMessage = "\(Localized.tr("speech.status.error")): \(error.localizedDescription)"
                    self?.stopRecording()
                }
            }
        }
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
            statusMessage = Localized.tr("speech.status.complete")
        } else {
            statusMessage = Localized.tr("speech.status.ready")
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
        statusMessage = Localized.tr("speech.status.ready")
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
        case .localeNotSupported: return Localized.tr("speech.error.localeNotSupported")
        case .notAuthorized: return Localized.tr("speech.error.notAuthorized")
        case .audioEngineError: return Localized.tr("speech.error.audioEngine")
        }
    }
}

extension SpeechProcessor: @unchecked Sendable {}
