// OCRScanView.swift
//
// 作者: Wang Chong
// 功能说明: struct OCRScanView
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

@preconcurrency import SwiftUI
import PhotosUI

// MARK: - OCR Scanner View
@MainActor
struct OCRScanView: View {
    @Environment(KMStore.self) var store
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: WikiImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var targetTitle = ""
    @State private var targetType: PageType = .source
    @State private var targetCustomIcon: String? = nil
    @State private var targetTags: [String] = ["OCR", Localized.tr("ocr.scanTag")]
    @State private var showIconPicker = false
    @State private var showOCRError = false
    @State private var ocrErrorMessage = ""
    @State private var showAddTagInput = false
    @State private var newTagText = ""
    @Environment(\.dismiss) private var dismiss
    var onFinish: ((String, String) -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Image picker area
                    OCRImagePickerArea(
                        selectedImage: selectedImage,
                        isProcessing: isProcessing,
                        selectedPhoto: selectedPhoto,
                        onPhotoSelected: { loadImage(from: $0) },
                        onStartRecognition: startRecognition
                    )

                    // Recognized text
                    if !recognizedText.isEmpty {
                        OCRResultDisplay(
                            recognizedText: $recognizedText,
                            onCopy: copyToClipboard
                        )
                    }

                    // Save to wiki (Now just finishes and returns data)
                    if !recognizedText.isEmpty {
                        Button(action: {
                            onFinish?(targetTitle, recognizedText)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text(Localized.tr("ocr.confirmAndEdit"))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.wikiAccent)
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                        }
                        .padding(.top, 10)
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle(Localized.tr("ocr.title"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("cancel")) {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadImage(from: newValue)
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $targetCustomIcon)
            }
            .alert(Localized.tr("ocr.scanFailed"), isPresented: $showOCRError) {
                Button(L10n.Common.tr("ok"), role: .cancel) {}
            } message: {
                Text(ocrErrorMessage)
            }
            .alert(L10n.Editor.tr("addTag"), isPresented: $showAddTagInput) {
                TextField(L10n.Editor.tr("enterTag"), text: $newTagText)
                    .accessibilityIdentifier("enterTagName")
                Button(Localized.tr("ocr.addTag")) {
                    commitNewTag()
                }
                Button(L10n.Common.tr("cancel"), role: .cancel) {
                    newTagText = ""
                }
            } message: {
                Text(L10n.Editor.tr("enterTag"))
            }
        }
    }
    
    // MARK: - Actions
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = WikiImage(data: data) {
                selectedImage = image
            }
        }
    }
    
    private func startRecognition() {
        guard let image = selectedImage else { return }
        isProcessing = true
        
        Task {
            do {
                let text = try await store.recognizeText(from: image)
                await MainActor.run {
                    recognizedText = text
                    isProcessing = false
                    if targetTitle.isEmpty {
                        targetTitle = String(text.prefix(20)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                await MainActor.run {
                    ocrErrorMessage = error.localizedDescription
                    showOCRError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        WikiPasteboard.string = recognizedText
    }
    
    private func saveToWiki() {
        onFinish?(targetTitle, recognizedText)
        dismiss()
    }
    
    private func removeTag(_ tag: String) {
        targetTags.removeAll { $0 == tag }
    }
    
    private func addTag() {
        newTagText = ""
        showAddTagInput = true
    }

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !targetTags.contains(trimmed) {
            targetTags.append(trimmed)
        }
        newTagText = ""
    }
}
