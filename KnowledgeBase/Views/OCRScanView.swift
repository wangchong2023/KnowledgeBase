import SwiftUI
import PhotosUI

// MARK: - OCR Scanner View
struct OCRScanView: View {
    @EnvironmentObject var store: KMStore
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var targetTitle = ""
    @State private var targetType: PageType = .source
    @State private var targetCustomIcon: String? = nil
    @State private var targetTags: [String] = ["OCR", "扫描"]
    @State private var showIconPicker = false
    @State private var showOCRError = false
    @State private var ocrErrorMessage = ""
    @State private var showAddTagInput = false
    @State private var newTagText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Image picker area
                    imagePickerArea
                    
                    // Recognized text
                    if !recognizedText.isEmpty {
                        recognizedTextArea
                    }
                    
                    // Save to wiki
                    if !recognizedText.isEmpty {
                        saveToWikiSection
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle("OCR 文字识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadImage(from: newValue)
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $targetCustomIcon)
            }
            .alert("文字识别失败", isPresented: $showOCRError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(ocrErrorMessage)
            }
            .alert("添加标签", isPresented: $showAddTagInput) {
                TextField("输入标签名称", text: $newTagText)
                    .accessibilityIdentifier("输入标签名称")
                Button("添加") {
                    commitNewTag()
                }
                Button("取消", role: .cancel) {
                    newTagText = ""
                }
            } message: {
                Text("请输入标签名称")
            }
        }
    }
    
    // MARK: - Image Picker Area
    private var imagePickerArea: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
                    .shadow(color: .black.opacity(0.1), radius: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                            .stroke(Color.wikiBorder, lineWidth: 1)
                    )
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                    .fill(Color.wikiCard)
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 40))
                                .foregroundStyle(.wikiSecondary)
                            Text("选择图片进行文字识别")
                                .font(.subheadline)
                                .foregroundStyle(.wikiSecondary)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WikiUI.cardRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundStyle(.wikiBorder)
                    )
            }
            
            // Photo picker
            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("从相册选择", systemImage: "photo.on.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.wikiAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.wikiAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                }
                
                if selectedImage != nil {
                    Button(action: startRecognition) {
                        HStack(spacing: 6) {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? "识别中..." : "识别文字")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.wikiAccent, in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    // MARK: - Recognized Text Area
    private var recognizedTextArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("识别结果", systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.wikiAccent)
                }
            }
            
            ScrollView {
                Text(recognizedText)
                    .font(.caption)
                    .foregroundStyle(.wikiText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(12)
            .background(Color.wikiCard, in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                    .stroke(Color.wikiBorder, lineWidth: 1)
            )
            
            HStack {
                Text("字数：\(recognizedText.count)")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Save to Wiki Section
    private var saveToWikiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("保存到知识库")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.wikiText)
            
            TextField("页面标题", text: $targetTitle)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
                .padding(10)
                .background(Color.wikiCard, in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                        .stroke(Color.wikiBorder, lineWidth: 1)
                )
            
            Picker("页面类型", selection: $targetType) {
                ForEach(PageType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Icon picker row
            HStack {
                Text("页面图标")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)

                Spacer()

                Button(action: { showIconPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: targetCustomIcon ?? targetType.icon)
                            .font(.body)
                            .foregroundStyle(targetCustomIcon != nil ? .wikiAccent : .wikiSecondary)
                            .frame(width: 28, height: 28)
                            .background((targetCustomIcon != nil ? Color.wikiAccent : targetType.themedColor).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))

                        Text(targetCustomIcon != nil ? "更换" : "自定义")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)

                        if targetCustomIcon != nil {
                            Button(action: { targetCustomIcon = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.wikiSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(targetTags, id: \.self) { tag in
                        TagPill(tag: tag, onRemove: { removeTag(tag) })
                    }
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)
                    }
                }
            }
            
            Button(action: saveToWiki) {
                Label("保存到知识库", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.wikiAccent, in: RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            }
        }
        .padding(16)
        .background(Color.wikiCard, in: RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
    
    // MARK: - Actions
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        }
    }
    
    private func startRecognition() {
        guard let image = selectedImage else { return }
        isProcessing = true
        
        Task {
            do {
                let text = try await OCRService.shared.recognizeText(from: image)
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
        UIPasteboard.general.string = recognizedText
    }
    
    private func saveToWiki() {
        guard !targetTitle.isEmpty, !recognizedText.isEmpty else { return }
        
        let _ = store.createPage(
            title: targetTitle,
            type: targetType,
            customIcon: targetCustomIcon,
            content: recognizedText,
            tags: targetTags
        )
        store.addLog(action: "OCR识别", target: targetTitle, details: "字数：\(recognizedText.count)")
        store.saveToDisk()
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

// MARK: - Tag Pill
private struct TagPill: View {
    let tag: String
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption2)
                .foregroundStyle(.wikiAccent)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.wikiSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.wikiAccent.opacity(0.1), in: Capsule())
    }
}
