import SwiftUI
import PhotosUI

// MARK: - OCR Image Picker Area
/// OCR 图片选择区域：显示选中图片或占位符 + 相册选择按钮 + 识别按钮
struct OCRImagePickerArea: View {
    let selectedImage: UIImage?
    let isProcessing: Bool
    let selectedPhoto: PhotosPickerItem?

    let onPhotoSelected: (PhotosPickerItem?) -> Void
    let onStartRecognition: () -> Void

    var body: some View {
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
                            Text(Localized.tr("ocr.selectImage"))
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
                PhotosPicker(selection: Binding(
                    get: { selectedPhoto },
                    set: { onPhotoSelected($0) }
                ), matching: .images) {
                    Label(Localized.tr("ocr.fromAlbum"), systemImage: "photo.on.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.wikiAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.wikiAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                }
                .accessibilityIdentifier("ocr-select-photo")

                if selectedImage != nil {
                    Button(action: onStartRecognition) {
                        HStack(spacing: 6) {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isProcessing ? Localized.tr("ocr.processing") : Localized.tr("ocr.recognize"))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.wikiAccent, in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                    }
                    .accessibilityIdentifier("ocr-start-recognition")
                    .disabled(isProcessing)
                }
            }
        }
    }
}

// MARK: - OCR Result Display
/// OCR 识别结果展示区：显示识别的文本和字符数统计
struct OCRResultDisplay: View {
    let recognizedText: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(Localized.tr("ocr.result"), systemImage: "doc.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.wikiText)

                Spacer()

                Button(action: onCopy) {
                    Label(Localized.tr("ocr.copy"), systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.wikiAccent)
                }
                .accessibilityIdentifier("ocr-copy-text")
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
                Text(Localized.trf("ocr.charCountFormat", recognizedText.count))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)

                Spacer()
            }
        }
    }
}

// MARK: - OCR Save Form
/// OCR 保存表单：页面标题/类型选择/图标/标签/保存按钮
struct OCRSaveForm: View {
    @Binding var targetTitle: String
    @Binding var targetType: PageType
    @Binding var targetCustomIcon: String?

    let targetTags: [String]
    let showIconPicker: Bool
    let showAddTagInput: Bool
    let newTagText: String

    let onIconPickerToggle: () -> Void
    let onCustomIconClear: () -> Void
    let onRemoveTag: (String) -> Void
    let onAddTag: () -> Void
    let onSave: () -> Void
    let onTagInputChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Localized.tr("ocr.saveToWiki"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.wikiText)

            TextField(Localized.tr("ocr.pageTitle"), text: $targetTitle)
                .font(.subheadline)
                .foregroundStyle(.wikiText)
                .padding(10)
                .background(Color.wikiCard, in: RoundedRectangle(cornerRadius: WikiUI.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: WikiUI.smallRadius)
                        .stroke(Color.wikiBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("ocr-page-title")

            Picker(Localized.tr("ocr.pageType"), selection: $targetType) {
                ForEach(PageType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Icon picker row
            HStack {
                Text(Localized.tr("page.icon"))
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)

                Spacer()

                Button(action: onIconPickerToggle) {
                    HStack(spacing: 6) {
                        Image(systemName: targetCustomIcon ?? targetType.icon)
                            .font(.body)
                            .foregroundStyle(targetCustomIcon != nil ? .wikiAccent : .wikiSecondary)
                            .frame(width: 28, height: 28)
                            .background((targetCustomIcon != nil ? Color.wikiAccent : targetType.themedColor).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.microRadius))

                        Text(targetCustomIcon != nil ? Localized.tr("ocr.changeIcon") : Localized.tr("ocr.customIcon"))
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)

                        if targetCustomIcon != nil {
                            Button(action: onCustomIconClear) {
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
                        TagPill(tag: tag, onRemove: { onRemoveTag(tag) })
                    }

                    Button(action: onAddTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)
                    }
                    .accessibilityIdentifier("ocr-add-tag")
                }
            }

            Button(action: onSave) {
                Label(Localized.tr("ocr.saveToWiki"), systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.wikiAccent, in: RoundedRectangle(cornerRadius: WikiUI.standardRadius))
            }
            .accessibilityIdentifier("ocr-save-to-wiki")
        }
        .padding(16)
        .background(Color.wikiCard, in: RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }
}

// MARK: - Tag Pill
/// 标签胶囊组件
struct TagPill: View {
    let tag: String
    var onRemove: () -> Void = {}

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
