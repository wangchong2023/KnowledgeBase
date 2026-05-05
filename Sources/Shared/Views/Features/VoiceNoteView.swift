// VoiceNoteView.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的语音笔记记录中心（VoiceNoteView），支持高效的语音输入、实时转写及知识提取。
// 该视图集成了原生语音识别引擎，通过以下核心功能点提升非结构化信息的捕获效率：
// 1. 实时波形可视化：通过音频电平检测技术实时渲染动态波形图，为用户提供直觉化的录音状态反馈。
// 2. 语音转文字（STT）：利用系统的语音识别框架实现流式文本转写，支持在录音过程中实时编辑与预览。
// 3. 智能摘要与入库：集成 LLM 对录音内容进行关键信息提取与总结，支持一键将语音笔记转化为标准的 Wiki 页面并自动打标。
// 4. 持久化与状态管理：通过 SpeechService 实现录音流程的生命周期控制，确保在后台或异常状态下语音数据的完整性与安全性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 升级全工程文档规范，修复 WikiUI 成员引用 Bug，优化波形图 UI 常量
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Voice Note View
/// 语音笔记功能主视图
struct VoiceNoteView: View {
    @StateObject private var speechService = SpeechProcessor()
    @Environment(KMStore.self) var store
    @State private var noteTitle = ""
    @State private var showSaveSheet = false
    @Environment(\.dismiss) private var dismiss
    var onFinish: ((String, String) -> Void)?
    
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
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
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
                    RoundedRectangle(cornerRadius: WikiUI.tiny)
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
                
                Button(action: { WikiPasteboard.string = speechService.transcribedText }) {
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
            
            TextEditor(text: $speechService.transcribedText)
                .font(.body)
                .foregroundStyle(.wikiText)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(Color.wikiBackground)
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                        .stroke(Color.wikiBorder, lineWidth: 1)
                )
            
            HStack {
                Text("\(speechService.transcribedText.count) \(Localized.tr("speech.characters"))")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                
                Spacer()
                
                Button(action: { 
                    onFinish?(Localized.tr("speech.defaultTitle"), speechService.transcribedText)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text(Localized.tr("speech.confirmAndEdit"))
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